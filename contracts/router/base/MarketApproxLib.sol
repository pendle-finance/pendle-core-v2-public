// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../core/libraries/math/Math.sol";
import "../../core/Market/MarketMathCore.sol";

struct ApproxParams {
    uint256 guessMin;
    uint256 guessMax;
    uint256 guessOffchain; // pass 0 in to skip this variable
    uint256 maxIteration; // every iteration, the diff between guessMin and guessMax will be divided by 2
    uint256 eps; // the max eps between the returned result & the correct result, base 1e18. Normally this number will be set
    // to 1e15 (1e18/1000 = 0.1%)

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
}

library MarketApproxPtInLib {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;

    struct ApproxParamsPtIn {
        uint256 guessMin;
        uint256 guessMax;
        uint256 guessOffchain;
        uint256 maxIteration;
        uint256 eps;
        //
        uint256 biggestGoodGuess;
    }

    struct Args1 {
        MarketState market;
        PYIndex index;
        uint256 minSyOut;
        uint256 blockTime;
    }

    /**
     * @dev algorithm:
        - Bin search the amount of PT to swap in
        - Try swapping & get netSyOut
        - Stop when netSyOut greater & approx minSyOut
        - guess & approx is for netPtIn
     */
    function approxSwapPtForExactSy(
        MarketState memory _market,
        PYIndex _index,
        uint256 _minSyOut,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtIn*/
            uint256, /*netSyOut*/
            uint256 /*netSyFee*/
        )
    {
        Args1 memory a = Args1(_market, _index, _minSyOut, _blockTime);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, 0, calcMaxPtIn(comp.totalAsset));

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, a.market.totalPt, iter);
            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(a.market, comp, a.index, guess);

            if (netSyOut >= a.minSyOut) {
                p.guessMax = guess;
                bool isAnswerAccepted = Math.isAGreaterApproxB(netSyOut, a.minSyOut, p.eps);
                if (isAnswerAccepted) {
                    return (guess, netSyOut, netSyFee);
                }
            } else {
                p.guessMin = guess;
            }
        }
        revert Errors.ApproxFail();
    }

    struct Args2 {
        MarketState market;
        PYIndex index;
        uint256 exactSyIn;
        uint256 blockTime;
    }

    /**
     * @dev algorithm:
        - Bin search the amount of PT to swap in
        - Flashswap the corresponding amount of SY out
        - Pair those amount with exactSyIn SY to tokenize into PT & YT
        - PT to repay the flashswap, YT transferred to user
        - Stop when PT to repay the flashswap greater approx the amount of PT owed
        - guess & approx is for netYtOut (also netPtIn)
     */
    function approxSwapExactSyForYt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _exactSyIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netYtOut*/
            uint256 /*netSyFee*/
        )
    {
        Args2 memory a = Args2(_market, _index, _exactSyIn, _blockTime);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);

        // at minimum we will flashswap exactSyIn since we have enough SY to payback the PT loan
        ApproxParamsPtIn memory p = newApproxParamsPtIn(
            _approx,
            a.index.syToAsset(a.exactSyIn),
            calcMaxPtIn(comp.totalAsset)
        );

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, a.market.totalPt, iter);
            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(a.market, comp, a.index, guess);

            uint256 maxPtPayable = a.index.syToAsset(netSyOut + a.exactSyIn);

            if (guess <= maxPtPayable) {
                p.guessMin = guess;
                bool isAnswerAccepted = Math.isASmallerApproxB(guess, maxPtPayable, p.eps);
                if (isAnswerAccepted) return (guess, netSyFee);
            } else {
                p.guessMax = guess;
            }
        }
        revert Errors.ApproxFail();
    }

    struct Args6 {
        MarketState market;
        PYIndex index;
        uint256 totalPtIn;
        uint256 blockTime;
    }

    /**
     * @dev algorithm:
        - Bin search the amount of PT to swap to SY
        - Swap PT to SY
        - Pair the remaining PT with the SY to add liquidity
        - Stop when the ratio of PT / totalPt & SY / totalSy is approx
        - guess & approx is for netPtSwap
     */
    function approxSwapPtToAddLiquidity(
        MarketState memory _market,
        PYIndex _index,
        uint256 _totalPtIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtSwap*/
            uint256, /*netSyFromSwap*/
            uint256 /*netSyFee*/
        )
    {
        Args6 memory a = Args6(_market, _index, _totalPtIn, _blockTime);
        require(a.market.totalLp != 0, "no existing lp");

        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(
            _approx,
            0,
            Math.min(a.totalPtIn, calcMaxPtIn(comp.totalAsset))
        );

        p.guessMax = Math.min(p.guessMax, a.totalPtIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, a.market.totalPt, iter);

            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netSyOut, uint256 netSyFee, uint256 netSyToReserve) = calcSyOut(
                a.market,
                comp,
                a.index,
                guess
            );

            uint256 syNumerator;
            uint256 ptNumerator;
            {
                uint256 newTotalPt = a.market.totalPt.Uint() + guess;
                uint256 newTotalSy = (a.market.totalSy.Uint() - netSyOut - netSyToReserve);

                // it is desired that
                // netSyOut / newTotalSy = netPtRemaining / newTotalPt
                // which is equivalent to
                // netSyOut * newTotalPt = netPtRemaining * newTotalSy

                syNumerator = netSyOut * newTotalPt;
                ptNumerator = (a.totalPtIn - guess) * newTotalSy;
            }

            if (Math.isAApproxB(syNumerator, ptNumerator, p.eps)) {
                return (guess, netSyOut, netSyFee);
            }

            if (syNumerator <= ptNumerator) {
                // needs more SY --> swap more PT
                p.guessMin = guess + 1;
            } else {
                // needs less SY --> swap less PT
                p.guessMax = guess - 1;
            }
        }
        revert Errors.ApproxFail();
    }

    struct Args7 {
        MarketState market;
        PYIndex index;
        uint256 exactPtIn;
        uint256 blockTime;
    }

    /**
     * @dev algorithm:
        - Bin search the amount of PT to swap to SY
        - Flashswap the corresponding amount of SY out
        - Tokenize all the SY into PT + YT
        - PT to repay the flashswap, YT transferred to user
        - Stop when the amount of PT owed is smaller approx the amount of PT to repay the flashswap
        - guess & approx is for totalPtToSwap
     */
    function approxSwapExactPtForYt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _exactPtIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netYtOut*/
            uint256, /*totalPtToSwap*/
            uint256 /*netSyFee*/
        )
    {
        Args7 memory a = Args7(_market, _index, _exactPtIn, _blockTime);

        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(
            _approx,
            a.exactPtIn,
            calcMaxPtIn(comp.totalAsset)
        );

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, a.market.totalPt, iter);

            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(a.market, comp, a.index, guess);

            uint256 netAssetOut = a.index.syToAsset(netSyOut);

            uint256 maxPtPayable = netAssetOut + a.exactPtIn;
            if (guess <= maxPtPayable) {
                p.guessMin = guess;
                if (Math.isASmallerApproxB(guess, maxPtPayable, p.eps)) {
                    return (netAssetOut, guess, netSyFee);
                }
            } else {
                p.guessMax = guess - 1;
            }
        }
        revert Errors.ApproxFail();
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcSyOut(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtIn
    )
        internal
        pure
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 netSyToReserve
        )
    {
        (int256 _netSyOut, int256 _netSyFee, int256 _netSyToReserve) = market.calcTrade(
            comp,
            index,
            netPtIn.neg()
        );
        netSyOut = _netSyOut.Uint();
        netSyFee = _netSyFee.Uint();
        netSyToReserve = _netSyToReserve.Uint();
    }

    function newApproxParamsPtIn(
        ApproxParams memory _approx,
        uint256 minGuessMin,
        uint256 maxGuessMax
    ) internal pure returns (ApproxParamsPtIn memory res) {
        res.guessMin = Math.max(_approx.guessMin, minGuessMin);
        res.guessMax = Math.min(_approx.guessMax, maxGuessMax);

        if (res.guessMin > res.guessMax || _approx.eps > Math.ONE)
            revert Errors.ApproxParamsInvalid(_approx.guessMin, _approx.guessMax, _approx.eps);

        res.guessOffchain = _approx.guessOffchain;
        res.maxIteration = _approx.maxIteration;
        res.eps = _approx.eps;
    }

    function calcMaxPtIn(int256 totalAsset) internal pure returns (uint256) {
        return totalAsset.Uint() - 1;
    }

    function nextGuess(
        ApproxParamsPtIn memory p,
        MarketPreCompute memory comp,
        int256 totalPt,
        uint256 iter
    ) internal pure returns (bool, uint256) {
        uint256 guess = _nextGuessPrivate(p, iter);
        if (guess <= p.biggestGoodGuess) return (true, guess);

        int256 slope = calcSlope(comp, totalPt, guess.Int());
        if (slope < 0) return (false, guess);

        p.biggestGoodGuess = guess;
        return (true, guess);
    }

    /**
     * @dev it is safe to assume that p.guessMin <= p.guessMax from the initialization of p
     * So once guessMin becomes larger, it should always be the case of ApproxFail
     */
    function _nextGuessPrivate(ApproxParamsPtIn memory p, uint256 iter)
        private
        pure
        returns (uint256)
    {
        if (iter == 0 && p.guessOffchain != 0) return p.guessOffchain;
        if (p.guessMin <= p.guessMax) return (p.guessMin + p.guessMax) / 2;
        revert Errors.ApproxFail();
    }

    function calcSlope(
        MarketPreCompute memory comp,
        int256 totalPt,
        int256 ptToMarket //
    ) internal pure returns (int256) {
        int256 diffAssetPtToMarket = comp.totalAsset - ptToMarket;
        int256 sumPt = ptToMarket + totalPt; // probably can skip sumPt check

        require(diffAssetPtToMarket > 0 && sumPt > 0, "invalid ptToMarket");

        int256 part1 = (ptToMarket * (totalPt + comp.totalAsset)).divDown(
            sumPt * diffAssetPtToMarket
        );

        int256 part2 = sumPt.divDown(diffAssetPtToMarket).ln();
        int256 part3 = Math.IONE.divDown(comp.rateScalar);

        return comp.rateAnchor - (part1 - part2).mulDown(part3);
    }
}

library MarketApproxPtOutLib {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;

    struct ApproxParamsPtOut {
        uint256 guessMin;
        uint256 guessMax;
        uint256 guessOffchain;
        uint256 maxIteration;
        uint256 eps;
    }

    struct Args4 {
        MarketState market;
        PYIndex index;
        uint256 exactSyIn;
        uint256 blockTime;
    }

    /**
     * @dev algorithm:
        - Bin search the amount of PT to swapExactOut
        - Calculate the amount of SY needed
        - Stop when the netSyIn is smaller approx exactSyIn
        - guess & approx is for netSyIn
     */
    function approxSwapExactSyForPt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _exactSyIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtOut*/
            uint256 /*netSyFee*/
        )
    {
        Args4 memory a = Args4(_market, _index, _exactSyIn, _blockTime);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(
            _approx,
            0,
            calcMaxPtOut(comp, a.market.totalPt)
        );

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netSyIn, uint256 netSyFee, ) = calcSyIn(a.market, comp, a.index, guess);

            if (netSyIn <= a.exactSyIn) {
                p.guessMin = guess;
                bool isAnswerAccepted = Math.isASmallerApproxB(netSyIn, a.exactSyIn, p.eps);
                if (isAnswerAccepted) return (guess, netSyFee);
            } else {
                p.guessMax = guess - 1;
            }
        }

        revert Errors.ApproxFail();
    }

    struct Args5 {
        MarketState market;
        PYIndex index;
        uint256 minSyOut;
        uint256 blockTime;
    }

    /**
     * @dev algorithm:
        - Bin search the amount of PT to swapExactOut
        - Flashswap that amount of PT & pair with YT to redeem SY
        - Use the SY to repay the flashswap debt and the remaining is transferred to user
        - Stop when the netSyOut is greater approx the minSyOut
        - guess & approx is for netSyOut
     */
    function approxSwapYtForExactSy(
        MarketState memory _market,
        PYIndex _index,
        uint256 _minSyOut,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netYtIn*/
            uint256, /*netSyOut*/
            uint256 /*netSyFee*/
        )
    {
        Args5 memory a = Args5(_market, _index, _minSyOut, _blockTime);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(
            _approx,
            0,
            calcMaxPtOut(comp, a.market.totalPt)
        );

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netSyOwed, uint256 netSyFee, ) = calcSyIn(a.market, comp, a.index, guess);

            uint256 netAssetToRepay = a.index.syToAssetUp(netSyOwed);
            uint256 netSyOut = a.index.assetToSy(guess - netAssetToRepay);

            if (netSyOut >= a.minSyOut) {
                p.guessMax = guess;
                if (Math.isAGreaterApproxB(netSyOut, a.minSyOut, p.eps)) {
                    return (guess, netSyOut, netSyFee);
                }
            } else {
                p.guessMin = guess + 1;
            }
        }
        revert Errors.ApproxFail();
    }

    struct Args6 {
        MarketState market;
        PYIndex index;
        uint256 totalSyIn;
        uint256 blockTime;
    }

    /**
     * @dev algorithm:
        - Bin search the amount of PT to swapExactOut
        - Swap that amount of PT out
        - Pair the remaining PT with the SY to add liquidity
        - Stop when the ratio of PT / totalPt & SY / totalSy is approx
        - guess & approx is for netPtFromSwap
     */
    function approxSwapSyToAddLiquidity(
        MarketState memory _market,
        PYIndex _index,
        uint256 _totalSyIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtFromSwap*/
            uint256, /*netSySwap*/
            uint256 /*netSyFee*/
        )
    {
        Args6 memory a = Args6(_market, _index, _totalSyIn, _blockTime);
        require(a.market.totalLp != 0, "no existing lp");

        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(
            _approx,
            0,
            calcMaxPtOut(comp, a.market.totalPt)
        );

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netSyIn, uint256 netSyFee, uint256 netSyToReserve) = calcSyIn(
                a.market,
                comp,
                a.index,
                guess
            );

            if (netSyIn > a.totalSyIn) {
                p.guessMax = guess - 1;
                continue;
            }

            uint256 syNumerator;
            uint256 ptNumerator;

            {
                uint256 newTotalPt = a.market.totalPt.Uint() - guess;
                uint256 netTotalSy = a.market.totalSy.Uint() + netSyIn - netSyToReserve;

                // it is desired that
                // netPtFromSwap / newTotalPt = netSyRemaining / netTotalSy
                // which is equivalent to
                // netPtFromSwap * netTotalSy = netSyRemaining * newTotalPt

                ptNumerator = guess * netTotalSy;
                syNumerator = (a.totalSyIn - netSyIn) * newTotalPt;
            }

            if (Math.isAApproxB(ptNumerator, syNumerator, p.eps)) {
                return (guess, netSyIn, netSyFee);
            }

            if (ptNumerator <= syNumerator) {
                // needs more PT
                p.guessMin = guess + 1;
            } else {
                // needs less PT
                p.guessMax = guess - 1;
            }
        }
        revert Errors.ApproxFail();
    }

    struct Args8 {
        MarketState market;
        PYIndex index;
        uint256 exactYtIn;
        uint256 blockTime;
        uint256 maxSyPayable;
    }

    /**
     * @dev algorithm:
        - Bin search the amount of PT to swapExactOut
        - Flashswap that amount of PT out
        - Pair all the PT with the YT to redeem SY
        - Use the SY to repay the flashswap debt
        - Stop when the amount of SY owed is smaller approx the amount of SY to repay the flashswap
        - guess & approx is for netPtFromSwap
     */
    function approxSwapExactYtForPt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _exactYtIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtOut*/
            uint256, /*totalPtSwapped*/
            uint256 /*netSyFee*/
        )
    {
        Args8 memory a = Args8(
            _market,
            _index,
            _exactYtIn,
            _blockTime,
            _index.assetToSy(_exactYtIn)
        );
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(
            _approx,
            a.exactYtIn,
            calcMaxPtOut(comp, a.market.totalPt)
        );

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netSyOwed, uint256 netSyFee, ) = calcSyIn(a.market, comp, a.index, guess);

            if (netSyOwed <= a.maxSyPayable) {
                p.guessMin = guess;
                if (Math.isASmallerApproxB(netSyOwed, a.maxSyPayable, p.eps)) {
                    return (guess - a.exactYtIn, guess, netSyFee);
                }
            } else {
                p.guessMax = guess - 1;
            }
        }
        revert Errors.ApproxFail();
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcSyIn(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtOut
    )
        internal
        pure
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 netSyToReserve
        )
    {
        (int256 _netSyIn, int256 _netSyFee, int256 _netSyToReserve) = market.calcTrade(
            comp,
            index,
            netPtOut.Int()
        );

        netSyIn = _netSyIn.abs();
        netSyFee = _netSyFee.Uint();
        netSyToReserve = _netSyToReserve.Uint();
    }

    function newApproxParamsPtOut(
        ApproxParams memory _approx,
        uint256 minGuessMin,
        uint256 maxGuessMax
    ) internal pure returns (ApproxParamsPtOut memory res) {
        if (_approx.guessMin > _approx.guessMax || _approx.eps > Math.ONE)
            revert Errors.ApproxParamsInvalid(_approx.guessMin, _approx.guessMax, _approx.eps);

        res.guessMin = Math.max(_approx.guessMin, minGuessMin);
        res.guessMax = Math.min(_approx.guessMax, maxGuessMax);

        if (res.guessMin > res.guessMax)
            revert Errors.ApproxBinarySearchInputInvalid(
                _approx.guessMin,
                _approx.guessMax,
                minGuessMin,
                maxGuessMax
            );

        res.guessOffchain = _approx.guessOffchain;
        res.maxIteration = _approx.maxIteration;
        res.eps = _approx.eps;
    }

    function calcMaxPtOut(MarketPreCompute memory comp, int256 totalPt)
        internal
        pure
        returns (uint256)
    {
        int256 logitP = (comp.feeRate - comp.rateAnchor).mulDown(comp.rateScalar).exp();
        int256 proportion = logitP.divDown(logitP + Math.IONE);
        int256 numerator = proportion.mulDown(totalPt + comp.totalAsset);
        int256 maxPtOut = totalPt - numerator;
        // only get 99.9% of the theoretical max to accommodate some precision issues
        return (maxPtOut.Uint() * 999) / 1000;
    }

    /**
     * @dev it is safe to assume that p.guessMin <= p.guessMax from the initialization of p
     * So once guessMin becomes larger, it should always be the case of ApproxFail
     */
    function nextGuess(ApproxParamsPtOut memory p, uint256 iter) private pure returns (uint256) {
        if (iter == 0 && p.guessOffchain != 0) return p.guessOffchain;
        if (p.guessMin <= p.guessMax) return (p.guessMin + p.guessMax) / 2;
        revert Errors.ApproxFail();
    }
}
