// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./Math.sol";
import "./MarketMathCore.sol";
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
    using SCYIndexLib for SCYIndex;
    using MarketMathCore for MarketState;

    struct SlotSwapPtForExactScy {
        uint256 ptInGuess;
        int256 _assetToAccount;
        uint256 netAssetOut;
    }

    function approxSwapPtForExactScy(
        MarketState memory market,
        SCYIndex index,
        uint256 minScyOut,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netPtIn*/
            uint256 /*netScyOut*/
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(minScyOut > 0, "invalid minScyOut");
        require(isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VARIABLES
        /// ------------------------------------------------------------
        uint256 minAssetOut = index.scyToAsset(minScyOut);
        uint256 largestGoodSlope;
        bool isSlopeNonNeg;

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtIn(market.totalPt, comp.totalAsset);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // ++iter at end of loop

            SlotSwapPtForExactScy memory slot;
            slot.ptInGuess = getCurrentGuess(iter, approx);

            /// ------------------------------------------------------------
            /// CHECK SLOPE
            /// ------------------------------------------------------------
            (isSlopeNonNeg, largestGoodSlope) = updateSlope(
                market.totalPt,
                slot.ptInGuess,
                comp,
                largestGoodSlope
            );
            if (!isSlopeNonNeg) {
                approx.guessMax = slot.ptInGuess;
                continue;
            }

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (slot._assetToAccount, ) = market.calcTrade(comp, slot.ptInGuess.neg());
            slot.netAssetOut = slot._assetToAccount.Uint();

            if (slot.netAssetOut >= minAssetOut) {
                approx.guessMax = slot.ptInGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isAGreaterApproxB(slot.netAssetOut, minAssetOut, approx.eps)) {
                    return (slot.ptInGuess, index.assetToScy(slot.netAssetOut));
                }
            } else {
                approx.guessMin = slot.ptInGuess + 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function approxSwapExactScyForPt(
        MarketState memory market,
        SCYIndex index,
        uint256 maxScyIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netPtOut*/
            uint256 /*netScyIn*/
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(maxScyIn > 0, "invalid maxScyIn");
        require(isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VAIRBALES
        /// ------------------------------------------------------------
        uint256 maxAssetIn = index.scyToAsset(maxScyIn);

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            uint256 ptOutGuess = getCurrentGuess(iter, approx);

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, ptOutGuess.Int());
            uint256 netAssetIn = _assetToAccount.neg().Uint();

            if (netAssetIn <= maxAssetIn) {
                approx.guessMin = ptOutGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isASmallerApproxB(netAssetIn, maxAssetIn, approx.eps)) {
                    return (ptOutGuess, index.assetToScy(netAssetIn));
                }
            } else {
                approx.guessMax = ptOutGuess - 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    struct SlotSwapExactScyForYt {
        uint256 ptInGuess;
        int256 _assetToAccount;
        uint256 netAssetOut;
        uint256 amountAssetNeedMore;
    }

    function approxSwapExactScyForYt(
        MarketState memory market,
        SCYIndex index,
        uint256 maxScyIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netYtOut*/
            uint256 /*netScyIn*/
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(maxScyIn > 0, "invalid maxScyIn");
        require(isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VAIRBALES
        /// ------------------------------------------------------------
        uint256 maxAssetIn = index.scyToAsset(maxScyIn);
        uint256 largestGoodSlope;
        bool isSlopeNonNeg;

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtIn(market.totalPt, comp.totalAsset);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // iter++ at end of loop

            SlotSwapExactScyForYt memory slot;
            // ytOutGuess = ptInGuess

            slot.ptInGuess = getCurrentGuess(iter, approx);

            /// ------------------------------------------------------------
            /// CHECK SLOPE
            /// ------------------------------------------------------------
            (isSlopeNonNeg, largestGoodSlope) = updateSlope(
                market.totalPt,
                slot.ptInGuess,
                comp,
                largestGoodSlope
            );
            if (!isSlopeNonNeg) {
                approx.guessMax = slot.ptInGuess - 1;
                continue;
            }

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (slot._assetToAccount, ) = market.calcTrade(comp, slot.ptInGuess.neg());
            slot.netAssetOut = slot._assetToAccount.Uint();
            slot.amountAssetNeedMore = slot.ptInGuess - slot.netAssetOut;

            if (slot.amountAssetNeedMore <= maxAssetIn) {
                approx.guessMin = slot.ptInGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isASmallerApproxB(slot.amountAssetNeedMore, maxAssetIn, approx.eps)) {
                    return (slot.ptInGuess, index.assetToScy(slot.amountAssetNeedMore));
                }
            } else {
                approx.guessMax = slot.ptInGuess - 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function approxSwapYtForExactScy(
        MarketState memory market,
        SCYIndex index,
        uint256 minScyOut,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netYtIn*/
            uint256 /*netScyOut*/
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(minScyOut > 0, "invalid minScyOut");
        require(isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VAIRBALES
        /// ------------------------------------------------------------
        uint256 minAssetOut = index.scyToAsset(minScyOut);

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // iter++ at end of loop

            // ytInGuess = ptOutGuess
            uint256 ptOutGuess = getCurrentGuess(iter, approx);

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, ptOutGuess.Int());
            uint256 netAssetOwed = _assetToAccount.neg().Uint();

            // since ptOutGuess is between guessMin & guessMax, it's guaranteed that
            // there are enough Yt to pair with ptOut

            uint256 netAssetOut = ptOutGuess - netAssetOwed;

            if (netAssetOut >= minAssetOut) {
                approx.guessMax = ptOutGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isAGreaterApproxB(netAssetOut, minAssetOut, approx.eps)) {
                    return (ptOutGuess, index.assetToScy(netAssetOut));
                }
            } else {
                approx.guessMin = ptOutGuess + 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function approxSwapExactYtToPt(
        MarketState memory market,
        SCYIndex index,
        uint256 maxYtIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256 /**netYtIn */,
            uint256 /**netPtOut */
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(maxYtIn > 0, "invalid maxYtIn");
        require(isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VAIRBALES
        /// ------------------------------------------------------------
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // iter++ at end of loop
            uint256 ptOutGuess = getCurrentGuess(iter, approx);

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, ptOutGuess.Int());
            uint256 netAssetOwed = _assetToAccount.neg().Uint();

            // since it is guaranteed that all YT should be use for scy payback
            // we only need to compare netAssetOwed with maxYtIn

            if (netAssetOwed <= maxYtIn) {
                approx.guessMin = ptOutGuess;
                if (Math.isASmallerApproxB(netAssetOwed, maxYtIn, approx.eps)) {
                    return (netAssetOwed, ptOutGuess - netAssetOwed);
                }
            } else {
                approx.guessMax = ptOutGuess - 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function approxSwapYtToExactPt(
        MarketState memory market,
        SCYIndex index,
        uint256 minPtOut,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (
        uint256,
        uint256
    ) {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(minPtOut > 0, "invalid minPtOut");
        require(isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VAIRBALES
        /// ------------------------------------------------------------
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        if (approx.guessMin < minPtOut) {
            approx.guessMin = minPtOut;
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // iter++ at end of loop
            uint256 ptOutGuess = getCurrentGuess(iter, approx);

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, ptOutGuess.Int());
            uint256 netAssetOwed = _assetToAccount.neg().Uint();

            if (netAssetOwed <= ptOutGuess - minPtOut) {
                approx.guessMax = ptOutGuess;
                if (Math.isASmallerApproxB(minPtOut, ptOutGuess - netAssetOwed, approx.eps)) {
                    return (netAssetOwed, ptOutGuess - netAssetOwed);
                }
            } else {
                approx.guessMin = ptOutGuess + 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function approxSwapExactPtToYt(
        MarketState memory market,
        SCYIndex index,
        uint256 maxPtIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256 /**netPtIn */,
            uint256 /**netYtOut */
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(maxPtIn > 0, "invalid maxPtIn");
        require(isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VAIRBALES
        /// ------------------------------------------------------------
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // iter++ at end of loop

            uint256 ptInGuess = getCurrentGuess(iter, approx);

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, ptInGuess.neg());
            uint256 netAssetOut = _assetToAccount.Uint();

            if (netAssetOut + maxPtIn >= ptInGuess) {
                approx.guessMin = ptInGuess;
                if (Math.isASmallerApproxB(ptInGuess - netAssetOut, maxPtIn, approx.eps)) {
                    return (ptInGuess - netAssetOut, netAssetOut);
                }
            } else {
                approx.guessMax = ptInGuess - 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function approxSwapPtToExactYt(
        MarketState memory market,
        SCYIndex index,
        uint256 minYtOut,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        view
        returns (
            uint256 /**netPtIn */,
            uint256 /**ptInGuess */
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(minYtOut > 0, "invalid minYtOut");
        require(isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VAIRBALES
        /// ------------------------------------------------------------
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = calcMaxPtOut(market.totalPt, comp);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // iter++ at end of loop

            uint256 ptInGuess = getCurrentGuess(iter, approx);

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, ptInGuess.neg());
            uint256 netAssetOut = _assetToAccount.Uint();

            if (netAssetOut >= minYtOut) {
                approx.guessMax = ptInGuess;
                if (Math.isASmallerApproxB(minYtOut, netAssetOut, approx.eps)) {
                    return (ptInGuess - netAssetOut, netAssetOut);
                }
            } else {
                approx.guessMin = ptInGuess + 1;
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }

    function updateSlope(
        int256 totalPt,
        uint256 ptInGuess,
        MarketPreCompute memory comp,
        uint256 largestGoodSlope
    ) internal pure returns (bool isSlopeNonNeg, uint256 newLargestGoodSlop) {
        if (ptInGuess <= largestGoodSlope) {
            return (true, largestGoodSlope);
        }
        // it's not guaranteed that the current slop is good
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
        int256 logitP = (Math.IONE.mulDown(comp.lnFeeRate) - comp.rateAnchor)
            .mulDown(comp.rateScalar)
            .exp();
        int256 proportion = logitP.divDown(logitP + Math.IONE);
        int256 numerator = proportion.mulDown(totalPt + comp.totalAsset);
        int256 maxPtOut = totalPt - numerator;
        // only get 99.9% of the theoretical max to accommodate some precision issues
        return (maxPtOut.Uint() * 999) / 1000;
    }

    function calcMaxPtIn(int256 totalPt, int256 totalAsset) internal pure returns (uint256) {
        return Math.min(totalPt, totalAsset).Uint() - 1;
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
        else return (approx.guessMin + approx.guessMax) / 2;
    }
}
