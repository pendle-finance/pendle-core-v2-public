// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

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
            uint256 /*netScyToReserve*/
        )
    {
        /*
        the algorithm is essentially to:
        1. binary search netPtIn
        2. if netScyOut is greater & approx minScyOut => answer found
        */

        Args1 memory arg = Args1(_market, _index, _minScyOut, _blockTime);
        MarketPreCompute memory comp = arg.market.getMarketPreCompute(arg.index, arg.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, comp.totalAsset);

        uint256 minAssetOut = arg.index.scyToAssetUp(arg.minScyOut);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, arg.market.totalPt, iter);

            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netAssetOut, uint256 netAssetToReserve) = calcAssetOut(
                arg.market,
                comp,
                guess
            );

            if (netAssetOut >= minAssetOut) {
                p.guessMax = guess;
                bool isAnswerAccepted = Math.isAGreaterApproxB(netAssetOut, minAssetOut, p.eps);
                if (isAnswerAccepted) {
                    return (
                        guess,
                        arg.index.assetToScy(netAssetOut),
                        arg.index.assetToScy(netAssetToReserve)
                    );
                }
            } else {
                p.guessMin = guess;
            }
        }
        revert("approx fail");
    }

    struct Args2 {
        MarketState market;
        PYIndex index;
        uint256 maxScyIn;
        uint256 blockTime;
    }

    function approxSwapExactScyForYt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _maxScyIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netYtOut*/
            uint256, /*netScyIn*/
            uint256 /*netScyToReserve*/
        )
    {
        /*
        the algorithm is essentially to:
        1. Binary search netPtIn (therefore netScyOut)
        2. flashswap some netScyOut (now we owe netPtIn)
        3. Use netScyOut + additional SCY from user => convert to PT + YT
        4. Pay back PT & give user YT.
        5. If the PT loan can be successfully & amount of additional SCY is smallerApprox maxScyIn
        => answer found
        */

        Args2 memory arg = Args2(_market, _index, _maxScyIn, _blockTime);
        MarketPreCompute memory comp = arg.market.getMarketPreCompute(arg.index, arg.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, comp.totalAsset);

        uint256 maxAssetIn = arg.index.scyToAsset(arg.maxScyIn);

        // at minimum we will flashswap maxAssetIn since we have enough SCY to payback the PT loan
        if (p.guessMin == 0) p.guessMin = maxAssetIn;

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            // ytOutGuess = ptInGuess
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, arg.market.totalPt, iter);
            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netAssetOut, uint256 netAssetToReserve) = calcAssetOut(
                arg.market,
                comp,
                guess
            );

            uint256 netAssetToPull = guess - netAssetOut;

            if (netAssetToPull <= maxAssetIn) {
                p.guessMin = guess;
                bool isAnswerAccepted = Math.isASmallerApproxB(netAssetToPull, maxAssetIn, p.eps);
                if (isAnswerAccepted)
                    return (
                        guess,
                        arg.index.assetToScy(netAssetToPull),
                        arg.index.assetToScy(netAssetToReserve)
                    );
            } else {
                p.guessMax = guess;
            }
        }
        revert("approx fail");
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
            uint256 /*netScyToReserve*/
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

        Args6 memory arg = Args6(_market, _index, _totalPtIn, _blockTime);
        require(arg.market.totalLp != 0, "no existing lp");

        MarketPreCompute memory comp = arg.market.getMarketPreCompute(arg.index, arg.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, comp.totalAsset);

        p.guessMax = Math.min(p.guessMax, arg.totalPtIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, arg.market.totalPt, iter);

            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netAssetOut, uint256 netAssetToReserve) = calcAssetOut(
                arg.market,
                comp,
                guess
            );

            uint256 assetNumerator;
            uint256 ptNumerator;
            {
                uint256 newTotalPt = arg.market.totalPt.Uint() + guess;
                uint256 netPtRemaining = arg.totalPtIn - guess;
                uint256 newTotalAsset = (comp.totalAsset.Uint() - netAssetOut - netAssetToReserve);

                // it is desired that
                // netAssetOut / newTotalAsset = netPtRemaining / newTotalPt
                // which is equivalent to
                // netAssetOut * newTotalPt = netPtRemaining * newTotalAsset

                assetNumerator = netAssetOut * newTotalPt;
                ptNumerator = netPtRemaining * newTotalAsset;
            }

            if (Math.isAApproxB(assetNumerator, ptNumerator, p.eps)) {
                return (
                    guess,
                    arg.index.assetToScy(netAssetOut),
                    arg.index.assetToScy(netAssetToReserve)
                );
            }

            if (assetNumerator <= ptNumerator) {
                // needs more asset --> swap more PT
                p.guessMin = guess + 1;
            } else {
                // needs less asset --> swap less PT
                p.guessMax = guess - 1;
            }
        }
        revert("approx fail");
    }

    struct Args7 {
        MarketState market;
        PYIndex index;
        uint256 maxPtIn;
        uint256 blockTime;
    }

    function approxSwapExactPtForYt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _maxPtIn,
        uint256 _blockTime,
        ApproxParams memory _approx // approx for totalPtToSwap
    )
        internal
        pure
        returns (
            uint256, /*netYtOut*/
            uint256, /*netPtIn*/
            uint256, /*totalPtToSwap*/
            uint256 /*netScyToReserve*/
        )
    {
        Args7 memory arg = Args7(_market, _index, _maxPtIn, _blockTime);

        MarketPreCompute memory comp = arg.market.getMarketPreCompute(arg.index, arg.blockTime);
        ApproxParamsPtIn memory p = newApproxParamsPtIn(_approx, comp.totalAsset);

        p.guessMin = Math.max(p.guessMin, arg.maxPtIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            (bool isGoodSlope, uint256 guess) = nextGuess(p, comp, arg.market.totalPt, iter);

            if (!isGoodSlope) {
                p.guessMax = guess;
                continue;
            }

            (uint256 netAssetOut, uint256 netAssetToReserve) = calcAssetOut(
                arg.market,
                comp,
                guess
            );

            uint256 netPtPayable = netAssetOut + arg.maxPtIn;
            if (guess <= netPtPayable) {
                uint256 netPtIn = guess - netAssetOut; // guess >= netAssetOut (market invariant)
                if (Math.isASmallerApproxB(netPtIn, arg.maxPtIn, p.eps)) {
                    return (netAssetOut, netPtIn, guess, arg.index.assetToScy(netAssetToReserve));
                }
            } else {
                p.guessMax = guess - 1;
            }
        }
        revert("approx fail");
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcAssetOut(
        MarketState memory market,
        MarketPreCompute memory comp,
        uint256 netPtIn
    ) internal pure returns (uint256 netAssetOut, uint256 netAssetToReserve) {
        (int256 assetToAccount, int256 assetToReserve) = market.calcTrade(comp, netPtIn.neg());

        netAssetOut = assetToAccount.Uint();
        netAssetToReserve = assetToReserve.Uint();
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

        require(res.guessMin <= res.guessMax && res.eps <= Math.ONE, "invalid approx params");
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
        else if (p.guessMin > p.guessMax) return p.guessMax;
        else return (p.guessMin + p.guessMax) / 2;
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
        uint256 maxScyIn;
        uint256 blockTime;
    }

    function approxSwapExactScyForPt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _maxScyIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtOut*/
            uint256, /*netScyIn*/
            uint256 /*netScyToReserve*/
        )
    {
        /*
        1. Binary search netPtOut
        2. Calc netScyIn to swap to receive netPtOut
        2. If netScyIn < maxScyIn && netScyIn ~ maxScyIn => answer found
        */

        Args4 memory arg = Args4(_market, _index, _maxScyIn, _blockTime);
        MarketPreCompute memory comp = arg.market.getMarketPreCompute(arg.index, arg.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(_approx, comp, arg.market.totalPt);

        uint256 maxAssetIn = arg.index.scyToAsset(arg.maxScyIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netAssetIn, uint256 netAssetToReserve) = calcAssetIn(arg.market, comp, guess);

            if (netAssetIn <= maxAssetIn) {
                p.guessMin = guess;
                bool isAnswerAccepted = Math.isASmallerApproxB(netAssetIn, maxAssetIn, p.eps);
                if (isAnswerAccepted)
                    return (
                        guess,
                        arg.index.assetToScy(netAssetIn),
                        arg.index.assetToScy(netAssetToReserve)
                    );
            } else {
                p.guessMax = guess - 1;
            }
        }
        revert("approx fail");
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
            uint256 /*netScyToReserve*/
        )
    {
        /*
        1. Binary search netPtOut (therefore netScyIn)
        2. Flashswap netPtOut (now we owe netScyIn)
        3. Pair netPtOut with netYtIn Yt => get SCY (netPtOut == netYtIn)
        4. Pay back SCY & the exceed amount of SCY (netScyOut) is transferred out to user
        5. If netScyOut > minScyOut && netScyOut ~ minScyOut => answer found
        */

        Args5 memory arg = Args5(_market, _index, _minScyOut, _blockTime);
        MarketPreCompute memory comp = arg.market.getMarketPreCompute(arg.index, arg.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(_approx, comp, arg.market.totalPt);

        uint256 minAssetOut = arg.index.scyToAssetUp(arg.minScyOut);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netAssetOwed, uint256 netAssetToReserve) = calcAssetIn(
                arg.market,
                comp,
                guess
            );

            uint256 netAssetOut = guess - netAssetOwed;

            if (netAssetOut >= minAssetOut) {
                p.guessMax = guess;
                if (Math.isAGreaterApproxB(netAssetOut, minAssetOut, p.eps)) {
                    return (
                        guess,
                        arg.index.assetToScy(netAssetOut),
                        arg.index.assetToScy(netAssetToReserve)
                    );
                }
            } else {
                p.guessMin = guess + 1;
            }
        }
        revert("approx fail");
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
            uint256 /*netScyToReserve*/
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

        Args6 memory arg = Args6(_market, _index, _totalScyIn, _blockTime);
        require(arg.market.totalLp != 0, "no existing lp");

        MarketPreCompute memory comp = arg.market.getMarketPreCompute(arg.index, arg.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(_approx, comp, arg.market.totalPt);

        uint256 totalAssetIn = arg.index.scyToAsset(arg.totalScyIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netAssetIn, uint256 netAssetToReserve) = calcAssetIn(arg.market, comp, guess);

            if (netAssetIn > totalAssetIn) {
                p.guessMax = guess - 1;
                continue;
            }

            uint256 ptNumerator;
            uint256 assetNumerator;

            {
                uint256 netAssetRemaining = totalAssetIn - netAssetIn;
                uint256 newTotalPt = arg.market.totalPt.Uint() - guess;
                uint256 newTotalAsset = comp.totalAsset.Uint() + netAssetIn - netAssetToReserve;

                // it is desired that
                // guess / newTotalPt = netAssetRemaining / newTotalAsset
                // which is equivalent to
                // guess * newTotalAsset = netAssetRemaining * newTotalPt

                ptNumerator = guess * newTotalAsset;
                assetNumerator = netAssetRemaining * newTotalPt;
            }

            if (Math.isAApproxB(ptNumerator, assetNumerator, p.eps)) {
                return (
                    guess,
                    arg.index.assetToScy(netAssetIn),
                    arg.index.assetToScy(netAssetToReserve)
                );
            }

            if (ptNumerator <= assetNumerator) {
                // needs more PT
                p.guessMin = guess + 1;
            } else {
                // needs less PT
                p.guessMax = guess - 1;
            }
        }
        revert("approx fail");
    }

    struct Args8 {
        MarketState market;
        PYIndex index;
        uint256 maxYtIn;
        uint256 blockTime;
        uint256 maxScyRedeemableFromPY;
    }

    function approxSwapExactYtForPt(
        MarketState memory _market,
        PYIndex _index,
        uint256 _maxYtIn,
        uint256 _blockTime,
        ApproxParams memory _approx
    )
        internal
        pure
        returns (
            uint256, /*netPtOut*/
            uint256, /*netYtIn*/
            uint256, /*totalPtSwapped*/
            uint256 /*netScyToReserve*/
        )
    {
        Args8 memory arg = Args8(
            _market,
            _index,
            _maxYtIn,
            _blockTime,
            _index.assetToScy(_maxYtIn)
        );
        MarketPreCompute memory comp = arg.market.getMarketPreCompute(arg.index, arg.blockTime);
        ApproxParamsPtOut memory p = newApproxParamsPtOut(_approx, comp, arg.market.totalPt);

        p.guessMin = Math.max(p.guessMin, arg.maxYtIn);

        for (uint256 iter = 0; iter < p.maxIteration; ++iter) {
            uint256 guess = nextGuess(p, iter);

            (uint256 netAssetIn, uint256 netAssetToReserve) = calcAssetIn(arg.market, comp, guess);
            uint256 netScyIn = arg.index.assetToScyUp(netAssetIn);

            if (netScyIn <= arg.maxScyRedeemableFromPY) {
                p.guessMin = guess;
                if (Math.isASmallerApproxB(netAssetIn, arg.maxYtIn, p.eps)) {
                    return (
                        guess - arg.maxYtIn,
                        arg.maxYtIn,
                        guess,
                        arg.index.assetToScy(netAssetToReserve)
                    );
                }
            } else {
                p.guessMax = guess - 1;
            }
        }
        revert("approx fail");
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcAssetIn(
        MarketState memory market,
        MarketPreCompute memory comp,
        uint256 netPtOut
    ) internal pure returns (uint256 netAssetIn, uint256 netAssetToReserve) {
        (int256 assetToAccount, int256 assetToReserve) = market.calcTrade(comp, netPtOut.Int());

        netAssetIn = assetToAccount.abs();
        netAssetToReserve = assetToReserve.Uint();
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

        require(res.guessMin <= res.guessMax && res.eps <= Math.ONE, "invalid approx params");
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
        else if (p.guessMin > p.guessMax) return p.guessMax;
        else return (p.guessMin + p.guessMax) / 2;
    }
}
