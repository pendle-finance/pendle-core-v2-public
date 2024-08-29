// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../core/libraries/math/PMath.sol";
import "../../core/Market/MarketMathCore.sol";

struct ApproxParams {
    uint256 guessMin;
    uint256 guessMax;
    uint256 guessOffchain; // pass 0 in to skip this variable
    uint256 maxIteration; // every iteration, the diff between guessMin and guessMax will be divided by 2
    uint256 eps; // the max eps between the returned result & the correct result, base 1e18. Normally this number will be set
    // to 1e15 (1e18/1000 = 0.1%)
}

/// Further explanation of the eps. Take swapExactSyForPt for example. To calc the corresponding amount of Pt to swap out,
/// it's necessary to run an approximation algorithm, because by default there only exists the Pt to Sy formula
/// To approx, the 5 values above will have to be provided, and the approx process will run as follows:
/// mid = (guessMin + guessMax) / 2 // mid here is the current guess of the amount of Pt out
/// netSyNeed = calcSwapSyForExactPt(mid)
/// if (netSyNeed > exactSyIn) guessMax = mid - 1 // since the maximum Sy in can't exceed the exactSyIn
/// else guessMin = mid (1)
/// For the (1), since netSyNeed <= exactSyIn, the result might be usable. If the netSyNeed is within eps of
/// exactSyIn (ex eps=0.1% => we have used 99.9% the amount of Sy specified), mid will be chosen as the final guess result

/// for guessOffchain, this is to provide a shortcut to guessing. The offchain SDK can precalculate the exact result
/// before the tx is sent. When the tx reaches the contract, the guessOffchain will be checked first, and if it satisfies the
/// approximation, it will be used (and save all the guessing). It's expected that this shortcut will be used in most cases
/// except in cases that there is a trade in the same market right before the tx

enum ApproxStage {
    INITIAL,
    RANGE_SEARCHING,
    RESULT_FINDING
}

struct ApproxState {
    ApproxStage stage;
    uint256 searchRangeLowerBound;
    uint256 searchRangeUpperBound;
}

using ApproxStateLib for ApproxState;

/// A small library for determining the next guess from the current
/// `ApproxParams` state, dynamically adjusting the search range to fit the valid
/// result range.
library ApproxStateLib {
    function tightenApproxBound(ApproxState memory state, ApproxParams memory approx) internal pure {
        uint256 lower = state.searchRangeLowerBound;
        uint256 upper = state.searchRangeUpperBound;
        if (approx.guessMax < lower || approx.guessMin > upper)
            revert("Slippage: approx range outside of valid search range");
        if (approx.guessMin < lower) approx.guessMin = lower;
        if (approx.guessMax > upper) approx.guessMax = upper;
    }

    function clampEstimation(ApproxState memory state, uint256 estimation) internal pure returns (uint256) {
        uint256 lower = state.searchRangeLowerBound;
        uint256 upper = state.searchRangeUpperBound;
        if (estimation < lower) estimation = lower;
        if (estimation > upper) estimation = upper;
        return estimation;
    }

    function advanceDown(
        ApproxState memory state,
        uint256 guess,
        ApproxParams memory approx,
        bool excludeGuessFromRange
    ) internal pure returns (uint256 nextGuess) {
        approx.guessMax = guess;
        if (excludeGuessFromRange) approx.guessMax--;

        if (state.stage == ApproxStage.INITIAL) {
            state.stage = ApproxStage.RANGE_SEARCHING;
            return approx.guessMin;
        } else if (state.stage == ApproxStage.RANGE_SEARCHING) {
            if (guess == approx.guessMin) {
                if (guess == state.searchRangeLowerBound) revert("Slippage: search range underflow");
                // change guessMin to double the distance from it to guessOffchain
                uint256 boundDiff = approx.guessOffchain - approx.guessMin;
                approx.guessMin = PMath.subWithLowerBound(approx.guessMin, boundDiff, state.searchRangeLowerBound);
                return approx.guessMin;
            }
            state.stage = ApproxStage.RESULT_FINDING;
        }

        if (approx.guessMin <= approx.guessMax) nextGuess = (approx.guessMin + approx.guessMax) / 2;
        else revert("Slippage: guessMin > guessMax");
    }

    function advanceUp(
        ApproxState memory state,
        uint256 guess,
        ApproxParams memory approx,
        bool excludeGuessFromRange
    ) internal pure returns (uint256 nextGuess) {
        approx.guessMin = guess;
        if (excludeGuessFromRange) approx.guessMin++;

        if (state.stage == ApproxStage.INITIAL) {
            state.stage = ApproxStage.RANGE_SEARCHING;
            return approx.guessMax;
        } else if (state.stage == ApproxStage.RANGE_SEARCHING) {
            if (guess == approx.guessMax) {
                if (guess == state.searchRangeUpperBound) revert("Slippage: search range overflow");
                // change guessMax to double the distance from guessOffchain to it
                uint256 boundDiff = approx.guessMax - approx.guessOffchain;
                approx.guessMax = PMath.addWithUpperBound(approx.guessMax, boundDiff, state.searchRangeUpperBound);
                return approx.guessMax;
            }
            state.stage = ApproxStage.RESULT_FINDING;
        }

        if (approx.guessMin <= approx.guessMax) nextGuess = (approx.guessMin + approx.guessMax) / 2;
        else revert("Slippage: guessMin > guessMax");
    }
}

library MarketApproxPtInLib {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;

    uint256 internal constant GUESS_RANGE_SLIP = (5 * PMath.ONE) / 100;

    /**
     * @dev algorithm:
     *     - Bin search the amount of PT to swap in
     *     - Try swapping & get netSyOut
     *     - Stop when netSyOut greater & approx minSyOut
     *     - guess & approx is for netPtIn
     */
    function approxSwapPtForExactSy(
        MarketState memory market,
        PYIndex index,
        uint256 minSyOut,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256, /*netPtIn*/ uint256, /*netSyOut*/ uint256 /*netSyFee*/) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessOffchain == 0) {
            // no limit on min
            approx.guessMax = PMath.min(approx.guessMax, calcMaxPtIn(market, comp));
            validateApprox(approx);
        }

        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            uint256 guess = nextGuess(approx, iter);
            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(market, comp, index, guess);

            if (netSyOut >= minSyOut) {
                if (PMath.isAGreaterApproxB(netSyOut, minSyOut, approx.eps)) {
                    return (guess, netSyOut, netSyFee);
                }
                approx.guessMax = guess;
            } else {
                approx.guessMin = guess;
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    /**
     * @dev algorithm:
     *     - Bin search the amount of PT to swap in
     *     - Flashswap the corresponding amount of SY out
     *     - Pair those amount with exactSyIn SY to tokenize into PT & YT
     *     - PT to repay the flashswap, YT transferred to user
     *     - Stop when the amount of SY to be pulled to tokenize PT to repay loan approx the exactSyIn
     *     - guess & approx is for netYtOut (also netPtIn)
     */
    function approxSwapExactSyForYt(
        MarketState memory market,
        PYIndex index,
        uint256 exactSyIn,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256 /*netYtOut*/, uint256 /*netSyFee*/, uint256 /* iteration */) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        ApproxState memory state;
        if (approx.guessOffchain == 0) {
            state = ApproxState({
                stage: ApproxStage.INITIAL,
                searchRangeLowerBound: index.syToAsset(exactSyIn),
                searchRangeUpperBound: calcMaxPtIn(market, comp)
            });
            uint256 estimatedYtOut = MarketApproxEstimate.estimateSwapExactSyForYt(market, index, blockTime, exactSyIn);
            estimatedYtOut = state.clampEstimation(estimatedYtOut);

            approx.guessOffchain = estimatedYtOut;
            approx.guessMin = PMath.max(approx.guessMin, estimatedYtOut.slipDown(GUESS_RANGE_SLIP));
            // No slip estimatedYtOut for guess max,
            // Because the result should not exceed estimatedYtOut.
            approx.guessMax = PMath.min(approx.guessMax, estimatedYtOut);
            validateApprox(approx);
            state.tightenApproxBound(approx);
        } else {
            state.stage = ApproxStage.RESULT_FINDING;
        }

        // at minimum we will flashswap exactSyIn since we have enough SY to payback the PT loan

        uint256 guess = approx.guessOffchain;
        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(market, comp, index, guess);

            uint256 netSyToTokenizePt = index.assetToSyUp(guess);

            // for sure netSyToTokenizePt >= netSyOut since we are swapping PT to SY
            uint256 netSyToPull = netSyToTokenizePt - netSyOut;

            if (netSyToPull <= exactSyIn) {
                if (PMath.isASmallerApproxB(netSyToPull, exactSyIn, approx.eps)) {
                    return (guess, netSyFee, iter);
                }
                guess = state.advanceUp(guess, approx, /* excludeGuessFromRange= */ false);
            } else {
                guess = state.advanceDown(guess, approx, /* excludeGuessFromRange= */ true);
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    struct Args5 {
        MarketState market;
        PYIndex index;
        uint256 totalPtIn;
        uint256 netSyHolding;
        uint256 blockTime;
        ApproxParams approx;
    }

    /**
     * @dev algorithm:
     *     - Bin search the amount of PT to swap to SY
     *     - Swap PT to SY
     *     - Pair the remaining PT with the SY to add liquidity
     *     - Stop when the ratio of PT / totalPt & SY / totalSy is approx
     *     - guess & approx is for netPtSwap
     */
    function approxSwapPtToAddLiquidity(
        MarketState memory _market,
        PYIndex _index,
        uint256 _totalPtIn,
        uint256 _netSyHolding,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (uint256 /*netPtSwap*/, uint256 /*netSyFromSwap*/, uint256 /*netSyFee*/, uint256 /* iteration */)
    {
        // hoist approx params here to avoid stack too deep
        ApproxParams memory approx = _approx;
        Args5 memory a = Args5(_market, _index, _totalPtIn, _netSyHolding, _blockTime, approx);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxState memory state;
        if (approx.guessOffchain == 0) {
            state = ApproxState({
                stage: ApproxStage.INITIAL,
                searchRangeLowerBound: 0, // no bound for lower
                searchRangeUpperBound: PMath.min(a.totalPtIn, calcMaxPtIn(a.market, comp))
            });
            uint256 estimatedPtSwap = estimateSwapPtToAddLiquidity(a);
            estimatedPtSwap = state.clampEstimation(estimatedPtSwap);

            approx.guessOffchain = estimatedPtSwap;
            approx.guessMin = PMath.max(approx.guessMin, estimatedPtSwap.slipDown(GUESS_RANGE_SLIP));
            approx.guessMax = PMath.min(approx.guessMax, estimatedPtSwap.slipUp(GUESS_RANGE_SLIP));
            validateApprox(approx);
            state.tightenApproxBound(approx);
            require(a.market.totalLp != 0, "no existing lp");
        } else {
            state.stage = ApproxStage.RESULT_FINDING;
        }

        uint256 guess = approx.guessOffchain;
        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            (uint256 syNumerator, uint256 ptNumerator, uint256 netSyOut, uint256 netSyFee, ) = calcNumerators(
                a.market,
                a.index,
                a.totalPtIn,
                a.netSyHolding,
                comp,
                guess
            );

            if (PMath.isAApproxB(syNumerator, ptNumerator, approx.eps)) {
                return (guess, netSyOut, netSyFee, iter);
            }

            if (syNumerator <= ptNumerator) {
                // needs more SY --> swap more PT
                guess = state.advanceUp(guess, approx, /* excludeGuessFromRange= */ true);
            } else {
                // needs less SY --> swap less PT
                guess = state.advanceDown(guess, approx, /* excludeGuessFromRange= */ true);
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    function estimateSwapPtToAddLiquidity(Args5 memory a) internal pure returns (uint256 estimatedPtSwap) {
        (uint256 estimatedPtAdd, ) = MarketApproxEstimate.estimateAddLiquidity(
            a.market,
            a.index,
            a.blockTime,
            a.totalPtIn,
            a.netSyHolding
        );
        estimatedPtSwap = a.totalPtIn.subMax0(estimatedPtAdd);
    }

    function calcNumerators(
        MarketState memory market,
        PYIndex index,
        uint256 totalPtIn,
        uint256 netSyHolding,
        MarketPreCompute memory comp,
        uint256 guess
    )
        internal
        pure
        returns (uint256 syNumerator, uint256 ptNumerator, uint256 netSyOut, uint256 netSyFee, uint256 netSyToReserve)
    {
        (netSyOut, netSyFee, netSyToReserve) = calcSyOut(market, comp, index, guess);

        uint256 newTotalPt = uint256(market.totalPt) + guess;
        uint256 newTotalSy = (uint256(market.totalSy) - netSyOut - netSyToReserve);

        // it is desired that
        // (netSyOut + netSyHolding) / newTotalSy = netPtRemaining / newTotalPt
        // which is equivalent to
        // (netSyOut + netSyHolding) * newTotalPt = netPtRemaining * newTotalSy

        syNumerator = (netSyOut + netSyHolding) * newTotalPt;
        ptNumerator = (totalPtIn - guess) * newTotalSy;
    }

    /**
     * @dev algorithm:
     *     - Bin search the amount of PT to swap to SY
     *     - Flashswap the corresponding amount of SY out
     *     - Tokenize all the SY into PT + YT
     *     - PT to repay the flashswap, YT transferred to user
     *     - Stop when the additional amount of PT to pull to repay the loan approx the exactPtIn
     *     - guess & approx is for totalPtToSwap
     */
    function approxSwapExactPtForYt(
        MarketState memory market,
        PYIndex index,
        uint256 exactPtIn,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256, /*netYtOut*/ uint256, /*totalPtToSwap*/ uint256 /*netSyFee*/) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessOffchain == 0) {
            approx.guessMin = PMath.max(approx.guessMin, exactPtIn);
            approx.guessMax = PMath.min(approx.guessMax, calcMaxPtIn(market, comp));
            validateApprox(approx);
        }

        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            uint256 guess = nextGuess(approx, iter);

            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(market, comp, index, guess);

            uint256 netAssetOut = index.syToAsset(netSyOut);

            // guess >= netAssetOut since we are swapping PT to SY
            uint256 netPtToPull = guess - netAssetOut;

            if (netPtToPull <= exactPtIn) {
                if (PMath.isASmallerApproxB(netPtToPull, exactPtIn, approx.eps)) {
                    return (netAssetOut, guess, netSyFee);
                }
                approx.guessMin = guess;
            } else {
                approx.guessMax = guess - 1;
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcSyOut(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtIn
    ) internal pure returns (uint256 netSyOut, uint256 netSyFee, uint256 netSyToReserve) {
        (int256 _netSyOut, int256 _netSyFee, int256 _netSyToReserve) = market.calcTrade(comp, index, -int256(netPtIn));
        netSyOut = uint256(_netSyOut);
        netSyFee = uint256(_netSyFee);
        netSyToReserve = uint256(_netSyToReserve);
    }

    function nextGuess(ApproxParams memory approx, uint256 iter) internal pure returns (uint256) {
        if (iter == 0 && approx.guessOffchain != 0) return approx.guessOffchain;
        if (approx.guessMin <= approx.guessMax) return (approx.guessMin + approx.guessMax) / 2;
        revert("Slippage: guessMin > guessMax");
    }

    /// INTENDED TO BE CALLED BY WHEN GUESS.OFFCHAIN == 0 ONLY ///

    function validateApprox(ApproxParams memory approx) internal pure {
        if (approx.guessMin > approx.guessMax || approx.eps > PMath.ONE) revert("Internal: INVALID_APPROX_PARAMS");
    }

    function calcMaxPtIn(MarketState memory market, MarketPreCompute memory comp) internal pure returns (uint256) {
        uint256 low = 0;
        uint256 hi = uint256(comp.totalAsset) - 1;

        while (low != hi) {
            uint256 mid = (low + hi + 1) / 2;
            if (calcSlope(comp, market.totalPt, int256(mid)) < 0) hi = mid - 1;
            else low = mid;
        }

        low = PMath.min(
            low,
            (MarketMathCore.MAX_MARKET_PROPORTION.mulDown(market.totalPt + comp.totalAsset) - market.totalPt).Uint()
        );

        return low;
    }

    function calcSlope(MarketPreCompute memory comp, int256 totalPt, int256 ptToMarket) internal pure returns (int256) {
        int256 diffAssetPtToMarket = comp.totalAsset - ptToMarket;
        int256 sumPt = ptToMarket + totalPt;

        require(diffAssetPtToMarket > 0 && sumPt > 0, "invalid ptToMarket");

        int256 part1 = (ptToMarket * (totalPt + comp.totalAsset)).divDown(sumPt * diffAssetPtToMarket);

        int256 part2 = sumPt.divDown(diffAssetPtToMarket).ln();
        int256 part3 = PMath.IONE.divDown(comp.rateScalar);

        return comp.rateAnchor - (part1 - part2).mulDown(part3);
    }
}

library MarketApproxPtOutLib {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;

    uint256 internal constant GUESS_RANGE_SLIP = (5 * PMath.ONE) / 100;

    /**
     * @dev algorithm:
     *     - Bin search the amount of PT to swapExactOut
     *     - Calculate the amount of SY needed
     *     - Stop when the netSyIn is smaller approx exactSyIn
     *     - guess & approx is for netSyIn
     */
    function approxSwapExactSyForPt(
        MarketState memory market,
        PYIndex index,
        uint256 exactSyIn,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256 /*netPtOut*/, uint256 /*netSyFee*/, uint256 /* iteration */) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        ApproxState memory state;
        if (approx.guessOffchain == 0) {
            state = ApproxState({
                stage: ApproxStage.INITIAL,
                searchRangeLowerBound: 0, // no bound for lower
                searchRangeUpperBound: calcMaxPtOut(comp, market.totalPt)
            });
            uint256 estimatedPtOut = MarketApproxEstimate.estimateSwapExactSyForPt(market, index, blockTime, exactSyIn);
            estimatedPtOut = state.clampEstimation(estimatedPtOut);

            approx.guessOffchain = estimatedPtOut;
            approx.guessMin = PMath.max(approx.guessMin, estimatedPtOut.slipDown(GUESS_RANGE_SLIP));
            // No slip estimatedPtOut for guess max,
            // Because the result should not exceed estimatedPtOut.
            approx.guessMax = PMath.min(approx.guessMax, estimatedPtOut);
            validateApprox(approx);
            state.tightenApproxBound(approx);
        } else {
            state.stage = ApproxStage.RESULT_FINDING;
        }

        uint256 guess = approx.guessOffchain;

        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            (uint256 netSyIn, uint256 netSyFee, ) = calcSyIn(market, comp, index, guess);

            if (netSyIn <= exactSyIn) {
                if (PMath.isASmallerApproxB(netSyIn, exactSyIn, approx.eps)) {
                    return (guess, netSyFee, iter);
                }
                guess = state.advanceUp(guess, approx, /* excludeGuessFromRange= */ false);
            } else {
                guess = state.advanceDown(guess, approx, /* excludeGuessFromRange= */ true);
            }
        }

        revert("Slippage: APPROX_EXHAUSTED");
    }

    /**
     * @dev algorithm:
     *     - Bin search the amount of PT to swapExactOut
     *     - Flashswap that amount of PT & pair with YT to redeem SY
     *     - Use the SY to repay the flashswap debt and the remaining is transferred to user
     *     - Stop when the netSyOut is greater approx the minSyOut
     *     - guess & approx is for netSyOut
     */
    function approxSwapYtForExactSy(
        MarketState memory market,
        PYIndex index,
        uint256 minSyOut,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256, /*netYtIn*/ uint256, /*netSyOut*/ uint256 /*netSyFee*/) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessOffchain == 0) {
            // no limit on min
            approx.guessMax = PMath.min(approx.guessMax, calcMaxPtOut(comp, market.totalPt));
            validateApprox(approx);
        }

        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            uint256 guess = nextGuess(approx, iter);

            (uint256 netSyOwed, uint256 netSyFee, ) = calcSyIn(market, comp, index, guess);

            uint256 netAssetToRepay = index.syToAssetUp(netSyOwed);
            uint256 netSyOut = index.assetToSy(guess - netAssetToRepay);

            if (netSyOut >= minSyOut) {
                if (PMath.isAGreaterApproxB(netSyOut, minSyOut, approx.eps)) {
                    return (guess, netSyOut, netSyFee);
                }
                approx.guessMax = guess;
            } else {
                approx.guessMin = guess + 1;
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    struct Args6 {
        MarketState market;
        PYIndex index;
        uint256 totalSyIn;
        uint256 netPtHolding;
        uint256 blockTime;
        ApproxParams approx;
    }

    /**
     * @dev algorithm:
     *     - Bin search the amount of PT to swapExactOut
     *     - Swap that amount of PT out
     *     - Pair the remaining PT with the SY to add liquidity
     *     - Stop when the ratio of PT / totalPt & SY / totalSy is approx
     *     - guess & approx is for netPtFromSwap
     */
    function approxSwapSyToAddLiquidity(
        MarketState memory _market,
        PYIndex _index,
        uint256 _totalSyIn,
        uint256 _netPtHolding,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (uint256 /*netPtFromSwap*/, uint256 /*netSySwap*/, uint256 /*netSyFee*/, uint256 /* iteration */)
    {
        Args6 memory a = Args6(_market, _index, _totalSyIn, _netPtHolding, _blockTime, _approx);

        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxState memory state;
        if (a.approx.guessOffchain == 0) {
            state = ApproxState({
                stage: ApproxStage.INITIAL,
                searchRangeLowerBound: 0,
                searchRangeUpperBound: calcMaxPtOut(comp, a.market.totalPt)
            });
            uint256 estimatedPtSwap = estimateSwapSyToAddLiquidity(a);
            estimatedPtSwap = state.clampEstimation(estimatedPtSwap);

            a.approx.guessOffchain = estimatedPtSwap;
            a.approx.guessMin = PMath.max(a.approx.guessMin, estimatedPtSwap.slipDown(GUESS_RANGE_SLIP));
            a.approx.guessMax = PMath.min(a.approx.guessMax, estimatedPtSwap.slipUp(GUESS_RANGE_SLIP));
            validateApprox(a.approx);
            state.tightenApproxBound(a.approx);
            require(a.market.totalLp != 0, "no existing lp");
        } else {
            state.stage = ApproxStage.RESULT_FINDING;
        }

        uint256 guess = a.approx.guessOffchain;
        for (uint256 iter = 0; iter < a.approx.maxIteration; ++iter) {
            (uint256 netSyIn, uint256 netSyFee, uint256 netSyToReserve) = calcSyIn(a.market, comp, a.index, guess);

            if (netSyIn > a.totalSyIn) {
                a.approx.guessMax = guess - 1;
                continue;
            }

            uint256 syNumerator;
            uint256 ptNumerator;

            {
                uint256 newTotalPt = uint256(a.market.totalPt) - guess;
                uint256 netTotalSy = uint256(a.market.totalSy) + netSyIn - netSyToReserve;

                // it is desired that
                // (netPtFromSwap + netPtHolding) / newTotalPt = netSyRemaining / netTotalSy
                // which is equivalent to
                // (netPtFromSwap + netPtHolding) * netTotalSy = netSyRemaining * newTotalPt

                ptNumerator = (guess + a.netPtHolding) * netTotalSy;
                syNumerator = (a.totalSyIn - netSyIn) * newTotalPt;
            }

            if (PMath.isAApproxB(ptNumerator, syNumerator, a.approx.eps)) {
                return (guess, netSyIn, netSyFee, iter);
            }

            if (ptNumerator <= syNumerator) {
                // needs more PT
                guess = state.advanceUp(guess, a.approx, /* excludeGuessFromRange= */ true);
            } else {
                // needs less PT
                guess = state.advanceDown(guess, a.approx, /* excludeGuessFromRange= */ true);
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    function estimateSwapSyToAddLiquidity(Args6 memory a) internal pure returns (uint256 estimatedPtSwap) {
        (uint256 estimatedPtAdd, ) = MarketApproxEstimate.estimateAddLiquidity(
            a.market,
            a.index,
            a.blockTime,
            a.netPtHolding,
            a.totalSyIn
        );
        estimatedPtSwap = estimatedPtAdd.subMax0(a.netPtHolding);
    }

    /**
     * @dev algorithm:
     *     - Bin search the amount of PT to swapExactOut
     *     - Flashswap that amount of PT out
     *     - Pair all the PT with the YT to redeem SY
     *     - Use the SY to repay the flashswap debt
     *     - Stop when the amount of YT required to pair with PT is approx exactYtIn
     *     - guess & approx is for netPtFromSwap
     */
    function approxSwapExactYtForPt(
        MarketState memory market,
        PYIndex index,
        uint256 exactYtIn,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256, /*netPtOut*/ uint256, /*totalPtSwapped*/ uint256 /*netSyFee*/) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessOffchain == 0) {
            approx.guessMin = PMath.max(approx.guessMin, exactYtIn);
            approx.guessMax = PMath.min(approx.guessMax, calcMaxPtOut(comp, market.totalPt));
            validateApprox(approx);
        }

        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            uint256 guess = nextGuess(approx, iter);

            (uint256 netSyOwed, uint256 netSyFee, ) = calcSyIn(market, comp, index, guess);

            uint256 netYtToPull = index.syToAssetUp(netSyOwed);

            if (netYtToPull <= exactYtIn) {
                if (PMath.isASmallerApproxB(netYtToPull, exactYtIn, approx.eps)) {
                    return (guess - netYtToPull, guess, netSyFee);
                }
                approx.guessMin = guess;
            } else {
                approx.guessMax = guess - 1;
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcSyIn(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtOut
    ) internal pure returns (uint256 netSyIn, uint256 netSyFee, uint256 netSyToReserve) {
        (int256 _netSyIn, int256 _netSyFee, int256 _netSyToReserve) = market.calcTrade(comp, index, int256(netPtOut));

        // all safe since totalPt and totalSy is int128
        netSyIn = uint256(-_netSyIn);
        netSyFee = uint256(_netSyFee);
        netSyToReserve = uint256(_netSyToReserve);
    }

    function calcMaxPtOut(MarketPreCompute memory comp, int256 totalPt) internal pure returns (uint256) {
        int256 logitP = (comp.feeRate - comp.rateAnchor).mulDown(comp.rateScalar).exp();
        int256 proportion = logitP.divDown(logitP + PMath.IONE);
        int256 numerator = proportion.mulDown(totalPt + comp.totalAsset);
        int256 maxPtOut = totalPt - numerator;
        // only get 99.9% of the theoretical max to accommodate some precision issues
        return (uint256(maxPtOut) * 999) / 1000;
    }

    function nextGuess(ApproxParams memory approx, uint256 iter) internal pure returns (uint256) {
        if (iter == 0 && approx.guessOffchain != 0) return approx.guessOffchain;
        if (approx.guessMin <= approx.guessMax) return (approx.guessMin + approx.guessMax) / 2;
        revert("Slippage: guessMin > guessMax");
    }

    function validateApprox(ApproxParams memory approx) internal pure {
        if (approx.guessMin > approx.guessMax || approx.eps > PMath.ONE) revert("Internal: INVALID_APPROX_PARAMS");
    }
}

library MarketApproxEstimate {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;

    enum TokenType {
        PT,
        YT,
        SY
    }

    function estimateAmount(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime,
        uint256 amountIn,
        TokenType tokenIn,
        TokenType tokenOut
    ) internal pure returns (uint256 estimatedAmountOut) {
        uint256 assetToPtRate = uint256(
            MarketMathCore._getExchangeRateFromImpliedRate(market.lastLnImpliedRate, market.expiry - blockTime)
        );

        uint256 ptToAssetRate = PMath.ONE.divDown(assetToPtRate);
        uint256 ytToAssetRate = PMath.ONE - ptToAssetRate;

        uint256 exactAssetIn;

        if (tokenIn == TokenType.SY) {
            exactAssetIn = index.syToAsset(amountIn);
        } else if (tokenIn == TokenType.PT) {
            exactAssetIn = amountIn.mulDown(ptToAssetRate);
        } else {
            exactAssetIn = amountIn.mulDown(ytToAssetRate);
        }

        if (tokenOut == TokenType.SY) {
            estimatedAmountOut = index.assetToSy(exactAssetIn);
        } else if (tokenOut == TokenType.PT) {
            estimatedAmountOut = exactAssetIn.divDown(ptToAssetRate);
        } else {
            estimatedAmountOut = exactAssetIn.divDown(ytToAssetRate);
        }
    }

    function estimateSwapExactSyForPt(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime,
        uint256 amountSyIn
    ) internal pure returns (uint256 estimatedPtOut) {
        return estimateAmount(market, index, blockTime, amountSyIn, TokenType.SY, TokenType.PT);
    }

    function estimateSwapExactSyForYt(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime,
        uint256 amountSyIn
    ) internal pure returns (uint256 estimatedYtOut) {
        return estimateAmount(market, index, blockTime, amountSyIn, TokenType.SY, TokenType.YT);
    }

    function estimateAddLiquidity(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime,
        uint256 netPtOwning,
        uint256 netSyOwning
    ) internal pure returns (uint256 estimatedPtToAdd, uint256 estimatedSyToAdd) {
        // Let `pa` be `estimatedPtToAdd`, `sa` be `estimatedSyToAdd`.

        // Conditions to satisfy:
        // +) Add liquidity amounts need to be proportional to the existing
        //    liquidity:
        //      pa / sa = totalPt / totalSy
        //   => pa = totalPt / totalSy * sa
        //
        // +) Let `syToPtRate` be the spot price between the PT and SY amount.
        //    Conversion between exessive/missing parts need to respect the
        //    current price:
        //      (sa - netSyOwning) * syToPtRate = netPtOwning - pa
        //  <=> (sa - netSyOwning) * syToPtRate = netPtOwning - totalPt / totalSy * sa
        //  <=> (sa - netSyOwning) * syToPtRate * totalSy = netPtOwning * totalSy - totalPt * sa
        //
        //  Let x = syToPtRate * totalSy (x can be calculated with the function `estimateAmount` above).
        //      (sa - netSyOwning) * x = netPtOwning * totalSy - totalPt * sa
        //  <=> sa * x - netSyOwning * x = netPtOwning * totalSy - totalPt * sa
        //  <=> sa * (x + totalPt) = netPtOwning * totalSy + netSyOwning * x

        uint256 totalSy = market.totalSy.Uint();
        uint256 totalPt = market.totalPt.Uint();
        uint256 x = estimateSwapExactSyForPt(market, index, blockTime, totalSy);
        uint256 sa = (netPtOwning * totalSy + netSyOwning * x) / (x + totalPt);
        uint256 pa = (totalPt * sa) / totalSy;

        return (pa, sa);
    }
}
