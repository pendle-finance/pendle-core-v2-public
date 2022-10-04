// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./Math.sol";
import "./MarketMathCore.sol";

struct ApproxParams {
    uint256 guessMin;
    uint256 guessMax;
    uint256 guessOffchain; // pass 0 in to skip this variable
    uint256 maxIteration; // every iteration, the diff between guessMin and guessMax will be divided by 2
    uint256 eps; // the max eps between the returned result & the correct result, base 1e18. Normally this number will be set
    // to 1e15 (1e18/1000 = 0.1%)

    /// Further explanation of the eps. Take swapExactScyForPt for example. To calc the corresponding amount of Pt to swap out,
    /// it's necessary to run an approximation algorithm, because by default there only exists the Pt to Scy formula
    /// To approx, the 5 values above will have to be provided, and the approx process will run as follows:
    /// mid = (guessMin + guessMax) / 2 // mid here is the current guess of the amount of Pt out
    /// netScyNeed = calcSwapScyForExactPt(mid)
    /// if (netScyNeed > exactScyIn) guessMax = mid - 1 // since the maximum Scy in can't exceed the exactScyIn
    /// else guessMin = mid (1)
    /// For the (1), since netScyNeed <= exactScyIn, the result might be usable. If the netScyNeed is within eps of
    /// exactScyIn (ex eps=0.1% => we have used 99.9% the amount of Scy specified), mid will be chosen as the final guess result

    /// for guessOffchain, this is to provide a shortcut to guessing. The offchain SDK can precalculate the exact result
    /// before the tx is sent. When the tx reaches the contract, the guessOffchain will be checked first, and if it satisfies the
    /// approximation, it will be used (and save all the guessing).
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
        uint256 minScyOut;
        uint256 blockTime;
    }

    function approxSwapPtForExactScy(
        MarketState memory _market,
        PYIndex _index,
        uint256 _minScyOut,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtIn*/
            uint256, /*netScyOut*/
            uint256 /*netScyFee*/
        )
    {
        /*
        the algorithm is essentially to:
        1. binary search netPtIn
        2. if netScyOut is greater & approx minScyOut => answer found
        */

        Args1 memory a = Args1(_market, _index, _minScyOut, _blockTime);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, comp.totalAsset);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, a.market.totalPt, iter);
            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netScyOut, uint256 netScyFee) = calcScyOut(a.market, comp, a.index, guess);

            if (netScyOut >= a.minScyOut) {
                p.guessMax = guess;
                bool isAnswerAccepted = Math.isAGreaterApproxB(netScyOut, a.minScyOut, p.eps);
                if (isAnswerAccepted) {
                    return (guess, netScyOut, netScyFee);
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
        uint256 exactScyIn;
        uint256 blockTime;
    }

    function approxSwapExactScyForYt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _exactScyIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netYtOut*/
            uint256 /*netScyFee*/
        )
    {
        Args2 memory a = Args2(_market, _index, _exactScyIn, _blockTime);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, comp.totalAsset);

        // at minimum we will flashswap exactScyIn since we have enough SCY to payback the PT loan
        if (p.guessMin == 0) p.guessMin = a.index.scyToAsset(a.exactScyIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            // ytOutGuess = ptInGuess
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, a.market.totalPt, iter);
            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netScyOut, uint256 netScyFee) = calcScyOut(a.market, comp, a.index, guess);

            uint256 maxPtPayable = a.index.scyToAsset(netScyOut + a.exactScyIn);

            if (guess <= maxPtPayable) {
                p.guessMin = guess;
                bool isAnswerAccepted = Math.isASmallerApproxB(guess, maxPtPayable, p.eps);
                if (isAnswerAccepted) return (guess, netScyFee);
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
            uint256, /*netScyFromSwap*/
            uint256 /*netScyFee*/
        )
    {
        /*
        The algorithm is essentially to:
        1. Binary search netPtIn (therefore netScyOut)
        2. Swap netPtIn for netScyOut
        3. Use (totalPtIn - netPtIn) and netScyOut to mint LP
        4. If (totalPtIn - netPtIn) / netScyOut ratio is close enough to the market's PT/SCY ratio
        => answer found

        Note that market maintains PT/SCY ratio, but here PT/asset is used instead
        */

        Args6 memory a = Args6(_market, _index, _totalPtIn, _blockTime);
        require(a.market.totalLp != 0, "no existing lp");

        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, comp.totalAsset);

        p.guessMax = Math.min(p.guessMax, a.totalPtIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, a.market.totalPt, iter);

            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netScyOut, uint256 netScyFee) = calcScyOut(a.market, comp, a.index, guess);

            uint256 scyNumerator;
            uint256 ptNumerator;
            {
                uint256 newTotalPt = a.market.totalPt.Uint() + guess;
                uint256 netPtRemaining = a.totalPtIn - guess;
                uint256 newTotalScy = (a.market.totalScy.Uint() - netScyOut - netScyFee);

                // it is desired that
                // netAssetOut / newTotalScy = netPtRemaining / newTotalPt
                // which is equivalent to
                // netAssetOut * newTotalPt = netPtRemaining * newTotalScy

                scyNumerator = netScyOut * newTotalPt;
                ptNumerator = netPtRemaining * newTotalScy;
            }

            if (Math.isAApproxB(scyNumerator, ptNumerator, p.eps)) {
                return (guess, netScyOut, netScyFee);
            }

            if (scyNumerator <= ptNumerator) {
                // needs more asset --> swap more PT
                p.guessMin = guess + 1;
            } else {
                // needs less asset --> swap less PT
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

    function approxSwapExactPtForYt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _exactPtIn,
        uint256 _blockTime,
        ApproxParams memory _approx // approx for totalPtToSwap
    )
        internal
        pure
        returns (
            uint256, /*netYtOut*/
            uint256, /*totalPtToSwap*/
            uint256 /*netScyFee*/
        )
    {
        Args7 memory a = Args7(_market, _index, _exactPtIn, _blockTime);

        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, comp.totalAsset);

        p.guessMin = Math.max(p.guessMin, a.exactPtIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, a.market.totalPt, iter);

            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netScyOut, uint256 netScyFee) = calcScyOut(a.market, comp, a.index, guess);

            uint256 netAssetOut = a.index.scyToAsset(netScyOut);

            uint256 maxPtPayable = netAssetOut + a.exactPtIn;
            if (guess <= maxPtPayable) {
                p.guessMin = guess;
                if (Math.isASmallerApproxB(guess, maxPtPayable, p.eps)) {
                    return (netAssetOut, guess, netScyFee);
                }
            } else {
                p.guessMax = guess - 1;
            }
        }
        revert Errors.ApproxFail();
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcScyOut(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtIn
    ) internal pure returns (uint256 netScyOut, uint256 netScyFee) {
        (int256 _netScyOut, int256 _netScyFee) = market.calcTrade(comp, index, netPtIn.neg());
        netScyOut = _netScyOut.Uint();
        netScyFee = _netScyFee.Uint();
    }

    function newApproxParamsPtIn(ApproxParams memory _approx, int256 totalAsset)
        internal
        pure
        returns (ApproxParamsPtIn memory res)
    {
        res.guessMin = _approx.guessMin;
        res.guessMax = Math.min(_approx.guessMax, calcMaxPtIn(totalAsset));
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

    function _nextGuessPrivate(ApproxParamsPtIn memory p, uint256 iter)
        private
        pure
        returns (uint256)
    {
        if (iter == 0 && p.guessOffchain != 0) return p.guessOffchain;
        if (p.guessMin <= p.guessMax) return (p.guessMin + p.guessMax) / 2;
        revert Errors.ApproxGuessRangeInvalid(p.guessMin, p.guessMax);
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
        uint256 exactScyIn;
        uint256 blockTime;
    }

    function approxSwapExactScyForPt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _exactScyIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtOut*/
            uint256 /*netScyFee*/
        )
    {
        /*
        1. Binary search netPtOut
        2. Calc netScyIn to swap to receive netPtOut
        2. If netScyIn < exactScyIn && netScyIn ~ exactScyIn => answer found
        */

        Args4 memory a = Args4(_market, _index, _exactScyIn, _blockTime);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(_approx, comp, a.market.totalPt);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netScyIn, uint256 netScyFee) = calcScyIn(a.market, comp, a.index, guess);

            if (netScyIn <= a.exactScyIn) {
                p.guessMin = guess;
                bool isAnswerAccepted = Math.isASmallerApproxB(netScyIn, a.exactScyIn, p.eps);
                if (isAnswerAccepted) return (guess, netScyFee);
            } else {
                p.guessMax = guess - 1;
            }
        }

        revert Errors.ApproxFail();
    }

    struct Args5 {
        MarketState market;
        PYIndex index;
        uint256 minScyOut;
        uint256 blockTime;
    }

    function approxSwapYtForExactScy(
        MarketState memory _market,
        PYIndex _index,
        uint256 _minScyOut,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netYtIn*/
            uint256, /*netScyOut*/
            uint256 /*netScyFee*/
        )
    {
        /*
        1. Binary search netPtOut (therefore netScyIn)
        2. Flashswap netPtOut (now we owe netScyIn)
        3. Pair netPtOut with netYtIn Yt => get SCY (netPtOut == netYtIn)
        4. Pay back SCY & the exceed amount of SCY (netScyOut) is transferred out to user
        5. If netScyOut > minScyOut && netScyOut ~ minScyOut => answer found
        */

        Args5 memory a = Args5(_market, _index, _minScyOut, _blockTime);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(_approx, comp, a.market.totalPt);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netScyOwed, uint256 netScyFee) = calcScyIn(a.market, comp, a.index, guess);

            uint256 netAssetToRepay = a.index.scyToAssetUp(netScyOwed);
            uint256 netScyOut = a.index.assetToScy(guess - netAssetToRepay);

            if (netScyOut >= a.minScyOut) {
                p.guessMax = guess;
                if (Math.isAGreaterApproxB(netScyOut, a.minScyOut, p.eps)) {
                    return (guess, netScyOut, netScyFee);
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
        uint256 totalScyIn;
        uint256 blockTime;
    }

    function approxSwapScyToAddLiquidity(
        MarketState memory _market,
        PYIndex _index,
        uint256 _totalScyIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtFromSwap*/
            uint256, /*netScySwap*/
            uint256 /*netScyFee*/
        )
    {
        /*
        1. Binary search netPtOut (therefore netScyIn)
        2. Swap netScyIn for netPtOut
        3. Use netPtOut and (totalScyIn - netScyIn) to mint LP
        4. If netPtOut / (totalScyIn - netScyIn) ratio is close enough to the market's PT/SCY ratio
        => answer found

        Note that market maintains PT/SCY ratio, but here PT/asset is used instead
        */

        Args6 memory a = Args6(_market, _index, _totalScyIn, _blockTime);
        require(a.market.totalLp != 0, "no existing lp");

        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(_approx, comp, a.market.totalPt);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netScyIn, uint256 netScyFee) = calcScyIn(a.market, comp, a.index, guess);

            if (netScyIn > a.totalScyIn) {
                p.guessMax = guess - 1;
                continue;
            }

            uint256 scyNumerator;
            uint256 ptNumerator;

            {
                uint256 netScyRemaining = a.totalScyIn - netScyIn;
                uint256 newTotalPt = a.market.totalPt.Uint() - guess;
                uint256 netTotalScy = comp.totalAsset.Uint() + netScyIn - netScyFee;

                // it is desired that
                // guess / newTotalPt = netScyRemaining / netTotalScy
                // which is equivalent to
                // guess * netTotalScy = netScyRemaining * newTotalPt

                ptNumerator = guess * netTotalScy;
                scyNumerator = netScyRemaining * newTotalPt;
            }

            if (Math.isAApproxB(ptNumerator, scyNumerator, p.eps)) {
                return (guess, netScyIn, netScyFee);
            }

            if (ptNumerator <= scyNumerator) {
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
        uint256 maxScyPayable;
    }

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
            uint256 /*netScyFee*/
        )
    {
        Args8 memory a = Args8(
            _market,
            _index,
            _exactYtIn,
            _blockTime,
            _index.assetToScy(_exactYtIn)
        );
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(_approx, comp, a.market.totalPt);

        p.guessMin = Math.max(p.guessMin, a.exactYtIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netScyOwed, uint256 netScyFee) = calcScyIn(a.market, comp, a.index, guess);

            if (netScyOwed <= a.maxScyPayable) {
                p.guessMin = guess;
                if (Math.isASmallerApproxB(netScyOwed, a.maxScyPayable, p.eps)) {
                    return (guess - a.exactYtIn, guess, netScyFee);
                }
            } else {
                p.guessMax = guess - 1;
            }
        }
        revert Errors.ApproxFail();
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcScyIn(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtOut
    ) internal pure returns (uint256 netScyIn, uint256 netScyFee) {
        (int256 _netScyIn, int256 _netScyFee) = market.calcTrade(comp, index, netPtOut.Int());

        netScyIn = _netScyIn.abs();
        netScyFee = _netScyFee.Uint();
    }

    function newApproxParamsPtOut(
        ApproxParams memory _approx,
        MarketPreCompute memory comp,
        int256 totalPt
    ) internal pure returns (ApproxParamsPtOut memory res) {
        res.guessMin = _approx.guessMin;
        res.guessMax = Math.min(_approx.guessMax, calcMaxPtOut(comp, totalPt));
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

    function nextGuess(ApproxParamsPtOut memory p, uint256 iter) private pure returns (uint256) {
        if (iter == 0 && p.guessOffchain != 0) return p.guessOffchain;
        if (p.guessMin <= p.guessMax) return (p.guessMin + p.guessMax) / 2;
        revert Errors.ApproxGuessRangeInvalid(p.guessMin, p.guessMax);
    }
}
