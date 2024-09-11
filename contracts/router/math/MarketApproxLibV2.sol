// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../core/libraries/math/PMath.sol";
import "../../core/Market/MarketMathCore.sol";
import {ApproxParams} from "../../interfaces/IPAllActionTypeV3.sol";
import {ApproxState} from "./ApproxStateLib.sol";
import {ApproxState, ApproxStateLib} from "./ApproxStateLib.sol";
import {MarketApproxEstimateLib} from "./MarketApproxEstimateLib.sol";

library MarketApproxPtInLibV2 {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;
    using MarketApproxEstimateLib for MarketState;

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
        ApproxParams memory _approx
    ) internal pure returns (uint256 /*netYtOut*/, uint256 /*netSyFee*/, uint256 /* iteration */) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        ApproxState memory state;
        if (_approx.guessOffchain == 0) {
            uint256 estimatedYtOut = market.estimateSwapExactSyForYt(index, blockTime, exactSyIn);
            uint256[2] memory hardBounds = [index.syToAsset(exactSyIn), calcSoftMaxPtIn(market, comp)];
            state = ApproxStateLib.initNoOffChain(estimatedYtOut, hardBounds);
        } else {
            state = ApproxStateLib.initWithOffchain(_approx);
        }

        // at minimum we will flashswap exactSyIn since we have enough SY to payback the PT loan

        for (uint256 iter = 0; iter < state.maxIteration; ++iter) {
            uint256 guess = state.curGuess;
            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(market, comp, index, guess);

            uint256 netSyToTokenizePt = index.assetToSyUp(guess);

            // for sure netSyToTokenizePt >= netSyOut since we are swapping PT to SY
            uint256 netSyToPull = netSyToTokenizePt - netSyOut;

            if (netSyToPull <= exactSyIn) {
                if (PMath.isASmallerApproxB(netSyToPull, exactSyIn, state.eps)) {
                    return (guess, netSyFee, iter);
                }
                state.transitionUp({excludeGuessFromRange: false});
            } else {
                state.transitionDown({excludeGuessFromRange: true});
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
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
        MarketState memory market,
        PYIndex index,
        uint256 totalPtIn,
        uint256 netSyHolding,
        uint256 blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (uint256 /*netPtSwap*/, uint256 /*netSyFromSwap*/, uint256 /*netSyFee*/, uint256 /* iteration */)
    {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        ApproxState memory state;
        if (_approx.guessOffchain == 0) {
            require(market.totalLp != 0, "no existing lp");

            (uint256 estimatedPtAdd, ) = market.estimateAddLiquidity(index, blockTime, totalPtIn, netSyHolding);
            uint256 estimatedPtSwap = totalPtIn.subMax0(estimatedPtAdd);
            uint256[2] memory hardBounds = [0, PMath.min(totalPtIn, calcSoftMaxPtIn(market, comp))];
            state = ApproxStateLib.initNoOffChain(estimatedPtSwap, hardBounds);
        } else {
            state = ApproxStateLib.initWithOffchain(_approx);
        }

        for (uint256 iter = 0; iter < state.maxIteration; ++iter) {
            uint256 guess = state.curGuess;
            (uint256 syNumerator, uint256 ptNumerator, uint256 netSyOut, uint256 netSyFee, ) = (
                calcNumerators(market, index, totalPtIn, netSyHolding, comp, guess)
            );

            if (PMath.isAApproxB(syNumerator, ptNumerator, state.eps)) {
                return (guess, netSyOut, netSyFee, iter);
            }

            if (syNumerator <= ptNumerator) {
                // needs more SY --> swap more PT
                state.transitionUp({excludeGuessFromRange: true});
            } else {
                // needs less SY --> swap less PT
                state.transitionDown({excludeGuessFromRange: true});
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
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

        low = PMath.min(low, calcSoftMaxPtIn(market, comp));
        return low;
    }

    function calcSoftMaxPtIn(MarketState memory market, MarketPreCompute memory comp) internal pure returns (uint256) {
        return (MarketMathCore.MAX_MARKET_PROPORTION.mulDown(market.totalPt + comp.totalAsset) - market.totalPt).Uint();
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

library MarketApproxPtOutLibV2 {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;
    using MarketApproxEstimateLib for MarketState;

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
        ApproxParams memory _approx
    ) internal pure returns (uint256 /*netPtOut*/, uint256 /*netSyFee*/, uint256 /* iteration */) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        ApproxState memory state;
        if (_approx.guessOffchain == 0) {
            uint256 estimatedPtOut = market.estimateSwapExactSyForPt(index, blockTime, exactSyIn);
            uint256[2] memory hardBounds = [0, calcMaxPtOut(comp, market.totalPt)];
            state = ApproxStateLib.initNoOffChain(estimatedPtOut, hardBounds);
        } else {
            state = ApproxStateLib.initWithOffchain(_approx);
        }

        for (uint256 iter = 0; iter < _approx.maxIteration; ++iter) {
            uint256 guess = state.curGuess;
            (uint256 netSyIn, uint256 netSyFee, ) = calcSyIn(market, comp, index, guess);

            if (netSyIn <= exactSyIn) {
                if (PMath.isASmallerApproxB(netSyIn, exactSyIn, _approx.eps)) {
                    return (guess, netSyFee, iter);
                }
                state.transitionUp({excludeGuessFromRange: false});
            } else {
                state.transitionDown({excludeGuessFromRange: true});
            }
        }

        revert("Slippage: APPROX_EXHAUSTED");
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
        MarketState memory market,
        PYIndex index,
        uint256 totalSyIn,
        uint256 netPtHolding,
        uint256 blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (uint256 /*netPtFromSwap*/, uint256 /*netSySwap*/, uint256 /*netSyFee*/, uint256 /* iteration */)
    {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        ApproxState memory state;
        if (_approx.guessOffchain == 0) {
            require(market.totalLp != 0, "no existing lp");

            (uint256 estimatedPtAdd, ) = market.estimateAddLiquidity(index, blockTime, netPtHolding, totalSyIn);
            uint256 estimatedPtSwap = estimatedPtAdd.subMax0(netPtHolding);
            uint256[2] memory hardBounds = [0, calcMaxPtOut(comp, market.totalPt)];
            state = ApproxStateLib.initNoOffChain(estimatedPtSwap, hardBounds);
        } else {
            state = ApproxStateLib.initWithOffchain(_approx);
        }

        for (uint256 iter = 0; iter < state.maxIteration; ++iter) {
            uint256 guess = state.curGuess;
            (uint256 netSyIn, uint256 netSyFee, uint256 netSyToReserve) = calcSyIn(market, comp, index, guess);

            if (netSyIn > totalSyIn) {
                state.transitionDown({excludeGuessFromRange: true});
                continue;
            }

            uint256 syNumerator;
            uint256 ptNumerator;

            {
                uint256 newTotalPt = uint256(market.totalPt) - guess;
                uint256 netTotalSy = uint256(market.totalSy) + netSyIn - netSyToReserve;

                // it is desired that
                // (netPtFromSwap + netPtHolding) / newTotalPt = netSyRemaining / netTotalSy
                // which is equivalent to
                // (netPtFromSwap + netPtHolding) * netTotalSy = netSyRemaining * newTotalPt

                ptNumerator = (guess + netPtHolding) * netTotalSy;
                syNumerator = (totalSyIn - netSyIn) * newTotalPt;
            }

            if (PMath.isAApproxB(ptNumerator, syNumerator, state.eps)) {
                return (guess, netSyIn, netSyFee, iter);
            }

            if (ptNumerator <= syNumerator) {
                // needs more PT
                state.transitionUp({excludeGuessFromRange: true});
            } else {
                // needs less PT
                state.transitionDown({excludeGuessFromRange: true});
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
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
