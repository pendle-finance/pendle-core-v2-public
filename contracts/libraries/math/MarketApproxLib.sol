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

// solhint-disable reason-string, ordering
library MarketApproxLib {
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;
    using PYIndexLib for PYIndex;
    using MarketMathCore for MarketState;

    struct VarsSwapPtForExactScy {
        uint256 netPtInGuess;
        int256 assetToAccount;
        int256 assetToReserve;
        uint256 netAssetOut;
        uint256 minAssetOut;
        uint256 largestGoodSlope;
        bool isSlopeNonNeg;
    }

    /// `guessMin` & `guessMax` is to guess the `netPtIn`

    function approxSwapPtForExactScy(
        MarketState memory market,
        PYIndex index,
        uint256 minScyOut,
        uint256 blockTime,
        ApproxParams memory approx
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

        Psuedo code:
        binary search netPtIn:
            netAssetOut = calcTrade(netPtIn)
            if (netScyOut >= minScyOut):
                guessMax = netPtIn;
                if (netScyOut `greaterApprox` minScyOut) => answer found
            else:
                guessMin = netPtIn;
        */

        require(isValidApproxParams(approx), "invalid approx approx");

        VarsSwapPtForExactScy memory vars;
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) approx.guessMax = calcMaxPtIn(comp.totalAsset);

        vars.minAssetOut = index.scyToAssetUp(minScyOut);

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            vars.netPtInGuess = getCurrentGuess(iter, approx);

            (vars.isSlopeNonNeg, vars.largestGoodSlope) = updateSlope(
                comp,
                market.totalPt,
                vars.netPtInGuess,
                vars.largestGoodSlope
            );
            if (!vars.isSlopeNonNeg) {
                approx.guessMax = vars.netPtInGuess;
                continue;
            }

            (vars.assetToAccount, vars.assetToReserve) = market.calcTrade(
                comp,
                vars.netPtInGuess.neg()
            );
            vars.netAssetOut = vars.assetToAccount.Uint();

            if (vars.netAssetOut >= vars.minAssetOut) {
                approx.guessMax = vars.netPtInGuess;
                bool isAnswerAccepted = Math.isAGreaterApproxB(
                    vars.netAssetOut,
                    vars.minAssetOut,
                    approx.eps
                );
                if (isAnswerAccepted)
                    return (
                        vars.netPtInGuess,
                        index.assetToScy(vars.netAssetOut),
                        index.assetToScy(vars.assetToReserve.Uint())
                    );
            } else {
                approx.guessMin = vars.netPtInGuess;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    struct VarsSwapExactScyForYt {
        uint256 netPtInGuess;
        int256 assetToAccount;
        int256 assetToReserve;
        uint256 netAssetOut;
        uint256 amountAssetNeedMore;
        uint256 largestGoodSlope;
        bool isSlopeNonNeg;
        uint256 maxAssetIn;
    }

    /// `guessMin` & `guessMax` is to guess the `netPtIn` == `netYtOut`
    function approxSwapExactScyForYt(
        MarketState memory market,
        PYIndex index,
        uint256 maxScyIn,
        uint256 blockTime,
        ApproxParams memory approx
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

        Psuedo code:
        maxAssetIn = maxScyIn -> asset
        binary search netPtIn:
            netAssetOut = calcTrade(netPtIn)
            totalAssetNeedMoreToConvertPt = netPtIn - netAssetOut
            if (totalAssetNeedMoreToConvertPt <= maxAssetIn):
                guessMin = netPtIn;
                if (totalAssetNeedMoreToConvertPt `smallerApprox` maxAssetIn) => answer found
            else:
                guessMax = netPtOut;
        */

        require(isValidApproxParams(approx), "invalid approx approx");

        VarsSwapExactScyForYt memory vars;
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        vars.maxAssetIn = index.scyToAsset(maxScyIn);

        if (approx.guessMax == type(uint256).max) approx.guessMax = calcMaxPtIn(comp.totalAsset);

        // at minimum we will flashswap maxAssetIn since we have enough SCY to payback the PT loan
        if (approx.guessMin == 0) approx.guessMin = vars.maxAssetIn;

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // ytOutGuess = ptInGuess
            vars.netPtInGuess = getCurrentGuess(iter, approx);

            (vars.isSlopeNonNeg, vars.largestGoodSlope) = updateSlope(
                comp,
                market.totalPt,
                vars.netPtInGuess,
                vars.largestGoodSlope
            );
            if (!vars.isSlopeNonNeg) {
                approx.guessMax = vars.netPtInGuess - 1;
                continue;
            }

            (vars.assetToAccount, vars.assetToReserve) = market.calcTrade(
                comp,
                vars.netPtInGuess.neg()
            );
            vars.netAssetOut = vars.assetToAccount.Uint();
            vars.amountAssetNeedMore = vars.netPtInGuess - vars.netAssetOut;

            if (vars.amountAssetNeedMore <= vars.maxAssetIn) {
                approx.guessMin = vars.netPtInGuess;
                bool isAnswerAccepted = Math.isASmallerApproxB(
                    vars.amountAssetNeedMore,
                    vars.maxAssetIn,
                    approx.eps
                );
                if (isAnswerAccepted)
                    return (
                        vars.netPtInGuess,
                        index.assetToScy(vars.amountAssetNeedMore),
                        index.assetToScy(vars.assetToReserve.Uint())
                    );
            } else {
                approx.guessMax = vars.netPtInGuess - 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    struct VarsSwapExactScyForPt {
        uint256 maxAssetIn;
        uint256 ptOutGuess;
        int256 assetToAccount;
        int256 assetToReserve;
        uint256 netAssetIn;
    }

    function approxSwapExactScyForPt(
        MarketState memory market,
        PYIndex index,
        uint256 maxScyIn,
        uint256 blockTime,
        ApproxParams memory approx
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
        the algorithm is essentially to:
        1. binary search netPtOut
        2. if netScyIn smaller & approx maxScyIn => answer found

        Psuedo code:
        maxAssetIn = maxScyIn -> asset
        binary search netPtOut:
            netAssetIn = calcTrade(netPtOut)
            if (netAssetIn <= maxAssetIn):
                guessMin = netPtOut
                if (netAssetIn `smallerApprox` maxAssetIn) => answer found
            else:
                guessMax = netPtOut;
        */

        require(isValidApproxParams(approx), "invalid approx approx");

        VarsSwapExactScyForPt memory vars;
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        vars.maxAssetIn = index.scyToAsset(maxScyIn);

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            vars.ptOutGuess = getCurrentGuess(iter, approx);
            (vars.assetToAccount, vars.assetToReserve) = market.calcTrade(
                comp,
                vars.ptOutGuess.Int()
            );
            vars.netAssetIn = vars.assetToAccount.abs();

            if (vars.netAssetIn <= vars.maxAssetIn) {
                approx.guessMin = vars.ptOutGuess;
                bool isAnswerAccepted = Math.isASmallerApproxB(
                    vars.netAssetIn,
                    vars.maxAssetIn,
                    approx.eps
                );
                if (isAnswerAccepted)
                    return (
                        vars.ptOutGuess,
                        index.assetToScy(vars.netAssetIn),
                        index.assetToScy(vars.assetToReserve.Uint())
                    );
            } else {
                approx.guessMax = vars.ptOutGuess;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    struct VarsSwapYtForExactScy {
        uint256 minAssetOut;
        uint256 ptOutGuess;
        int256 assetToAccount;
        int256 assetToReserve;
        uint256 netAssetOwed;
        uint256 netAssetOut;
    }

    function approxSwapYtForExactScy(
        MarketState memory market,
        PYIndex index,
        uint256 minScyOut,
        uint256 blockTime,
        ApproxParams memory approx
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
        the algorithm is essentially to:
        1. Binary search netPtOut (therefore netScyIn) (netYtIn == netPtOut)
        2. flashswap netPtOut (now we owe netScyIn)
        3. Pair netPtOut with the corresponding amount of Yt => redeem Scy
        4. Pay back Scy & the exceed amount of Scy (netScyOut) is transferred out to user
        5. If netScyOut is greater approx minScyOut => answer found

        Psuedo code:
        minAssetOut = minScyOut -> asset
        binary search netPtOut:
            netAssetIn = calcTrade(netPtOut)
            netAssetFromPtYt = netPtOut
            netAssetOut = netAssetFromPtYt - netAssetIn
            if (netAssetOut >= minAssetOut):
                guessMax = netPtOut
                if (netAssetOut `greaterApprox` minAssetOut) => answer found
            else:
                guessMin = netPtOut;
        */

        require(isValidApproxParams(approx), "invalid approx approx");

        VarsSwapYtForExactScy memory vars;
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        vars.minAssetOut = index.scyToAssetUp(minScyOut);

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // ytInGuess = ptOutGuess
            vars.ptOutGuess = getCurrentGuess(iter, approx);

            (vars.assetToAccount, vars.assetToReserve) = market.calcTrade(
                comp,
                vars.ptOutGuess.Int()
            );
            vars.netAssetOwed = vars.assetToAccount.abs();

            // since ptOutGuess is between guessMin & guessMax, it's guaranteed that
            // there are enough Yt to pair with ptOut

            vars.netAssetOut = vars.ptOutGuess - vars.netAssetOwed;

            if (vars.netAssetOut >= vars.minAssetOut) {
                approx.guessMax = vars.ptOutGuess;
                if (Math.isAGreaterApproxB(vars.netAssetOut, vars.minAssetOut, approx.eps)) {
                    return (
                        vars.ptOutGuess,
                        index.assetToScy(vars.netAssetOut),
                        index.assetToScy(vars.assetToReserve.Uint())
                    );
                }
            } else {
                approx.guessMin = vars.ptOutGuess + 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    struct VarsSwapPtToAddLiquidity {
        uint256 netPtInGuess;
        int256 assetToAccount;
        int256 assetToReserve;
        uint256 netAssetOut;
        uint256 netPtRemaining;
        uint256 newTotalPt;
        uint256 newTotalAsset;
        uint256 largestGoodSlope;
        uint256 assetNumerator;
        uint256 ptNumerator;
        bool isSlopeNonNeg;
    }

    function approxSwapPtToAddLiquidity(
        MarketState memory market,
        PYIndex index,
        uint256 netPtAdded,
        uint256 blockTime,
        ApproxParams memory approx
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
        The algorithm is essentially to:
        1. Binary search netPtIn (therefore netScyOut)
        2. Swap netPtIn for netScyOut
        3. Use (netPtAdded - netPtIn) and netScyOut to mint LP
        4. If (netPtAdded - netPtIn) / netScyOut ratio is close enough to the market's PT/SCY ratio
        => answer found

        Note that market maintains PT/SCY ratio, but here PT/asset is used instead
        */

        require(market.totalLp != 0, "no existing lp");

        VarsSwapPtToAddLiquidity memory vars;
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            // ensures that netPtIn is always valid and not greater than netPtAdded
            approx.guessMax = Math.min(calcMaxPtIn(comp.totalAsset), netPtAdded);
        }

        require(isValidApproxParams(approx), "invalid approx");

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            vars.netPtInGuess = getCurrentGuess(iter, approx);

            (vars.isSlopeNonNeg, vars.largestGoodSlope) = updateSlope(
                comp,
                market.totalPt,
                vars.netPtInGuess,
                vars.largestGoodSlope
            );
            if (!vars.isSlopeNonNeg) {
                approx.guessMax = vars.netPtInGuess;
                continue;
            }

            (vars.assetToAccount, vars.assetToReserve) = market.calcTrade(
                comp,
                vars.netPtInGuess.neg()
            );

            vars.netAssetOut = vars.assetToAccount.Uint();
            vars.netPtRemaining = netPtAdded - vars.netPtInGuess;
            vars.newTotalPt = market.totalPt.Uint() + vars.netPtInGuess;
            vars.newTotalAsset = (comp.totalAsset - vars.assetToAccount - vars.assetToReserve)
                .Uint();

            // it is desired that
            // netAssetOut / newTotalAsset = netPtRemaining / newTotalPt
            // which is equivalent to
            // netAssetOut * newTotalPt = netPtRemaining * newTotalAsset

            vars.assetNumerator = vars.netAssetOut * vars.newTotalPt;
            vars.ptNumerator = vars.netPtRemaining * vars.newTotalAsset;

            if (Math.isAApproxB(vars.assetNumerator, vars.ptNumerator, approx.eps)) {
                return (
                    vars.netPtInGuess,
                    index.assetToScy(vars.netAssetOut),
                    index.assetToScy(vars.assetToReserve.Uint())
                );
            }

            if (vars.assetNumerator <= vars.ptNumerator) {
                // needs more asset --> swap more PT
                approx.guessMin = vars.netPtInGuess + 1;
            } else {
                // needs less asset --> swap less PT
                approx.guessMax = vars.netPtInGuess - 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    struct VarsSwapScyToAddLiquidity {
        uint256 netAssetAdded;
        uint256 ptOutGuess;
        int256 assetToAccount;
        int256 assetToReserve;
        uint256 netAssetIn;
        uint256 netAssetRemaining;
        uint256 newTotalPt;
        uint256 newTotalAsset;
        uint256 ptNumerator;
        uint256 assetNumerator;
    }

    function approxSwapScyToAddLiquidity(
        MarketState memory market,
        PYIndex index,
        uint256 netScyAdded,
        uint256 blockTime,
        ApproxParams memory approx
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
        The algorithm is essentially to:
        1. Binary search netPtOut (therefore netScyIn)
        2. Swap netScyIn for netPtOut
        3. Use netPtOut and (netScyAdded - netScyIn) to mint LP
        4. If netPtOut / (netScyAdded - netScyIn) ratio is close enough to the market's PT/SCY ratio
        => answer found

        Note that market maintains PT/SCY ratio, but here PT/asset is used instead
        */
        require(market.totalLp != 0, "no existing lp");

        VarsSwapScyToAddLiquidity memory vars;
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        require(isValidApproxParams(approx), "invalid approx");

        vars.netAssetAdded = index.scyToAsset(netScyAdded);

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            vars.ptOutGuess = getCurrentGuess(iter, approx);
            (vars.assetToAccount, vars.assetToReserve) = market.calcTrade(
                comp,
                vars.ptOutGuess.Int()
            );

            vars.netAssetIn = vars.assetToAccount.abs();

            if (vars.netAssetIn > vars.netAssetAdded) {
                approx.guessMax = vars.ptOutGuess - 1;
                unchecked {
                    ++iter;
                }
                continue;
            }

            vars.netAssetRemaining = vars.netAssetAdded - vars.netAssetIn;
            vars.newTotalPt = market.totalPt.Uint() - vars.ptOutGuess;
            vars.newTotalAsset = (comp.totalAsset - vars.assetToAccount - vars.assetToReserve)
                .Uint();

            // it is desired that
            // ptOutGuess / newTotalPt = netAssetRemaining / newTotalAsset
            // which is equivalent to
            // ptOutGuess * newTotalAsset = netAssetRemaining * newTotalPt

            vars.ptNumerator = vars.ptOutGuess * vars.newTotalAsset;
            vars.assetNumerator = vars.netAssetRemaining * vars.newTotalPt;

            if (Math.isAApproxB(vars.ptNumerator, vars.assetNumerator, approx.eps)) {
                return (
                    vars.ptOutGuess,
                    index.assetToScy(vars.netAssetIn),
                    index.assetToScy(vars.assetToReserve.Uint())
                );
            }

            if (vars.ptNumerator <= vars.assetNumerator) {
                // needs more PT
                approx.guessMin = vars.ptOutGuess + 1;
            } else {
                // needs less PT
                approx.guessMax = vars.ptOutGuess - 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function updateSlope(
        MarketPreCompute memory comp,
        int256 totalPt,
        uint256 ptInGuess,
        uint256 largestGoodSlope
    ) internal pure returns (bool isSlopeNonNeg, uint256 newLargestGoodSlope) {
        if (ptInGuess <= largestGoodSlope) {
            return (true, largestGoodSlope);
        }
        // it's not guaranteed that the current slope is good
        // we therefore have to recalculate the slope
        int256 slope = slopeFactor(totalPt, ptInGuess.neg(), comp);
        if (slope >= 0) return (true, ptInGuess);
        else return (false, largestGoodSlope);
    }

    // ptToMarket < totalAsset && totalPt
    function slopeFactor(
        int256 totalPt,
        int256 ptToAccount,
        MarketPreCompute memory comp
    ) internal pure returns (int256) {
        int256 ptToMarket = -ptToAccount;
        int256 diffAssetPtToMarket = comp.totalAsset - ptToMarket;
        int256 sumPt = ptToMarket + totalPt;

        require(diffAssetPtToMarket > 0 && sumPt > 0, "invalid ptToMarket");

        int256 part1 = (ptToMarket * (totalPt + comp.totalAsset)).divDown(
            sumPt * diffAssetPtToMarket
        );

        int256 part2 = sumPt.divDown(diffAssetPtToMarket).ln();
        int256 part3 = Math.IONE.divDown(comp.rateScalar);

        return comp.rateAnchor - (part1 - part2).mulDown(part3);
    }

    function calcMaxPtOut(int256 totalPt, MarketPreCompute memory comp)
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

    function calcMaxPtIn(int256 totalAsset) internal pure returns (uint256) {
        return totalAsset.Uint() - 1;
    }

    function isValidApproxParams(ApproxParams memory approx) internal pure returns (bool) {
        return (approx.guessMin <= approx.guessMax && approx.eps <= Math.ONE);
    }

    function getCurrentGuess(uint256 iteration, ApproxParams memory approx)
        internal
        pure
        returns (uint256)
    {
        if (iteration == 0 && approx.guessOffchain != 0) return approx.guessOffchain;
        else {
            if (approx.guessMin > approx.guessMax) return approx.guessMax;
            return (approx.guessMin + approx.guessMax) / 2;
        }
    }
}
