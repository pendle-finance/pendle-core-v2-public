// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./Math.sol";
import "./MarketMathCore.sol";
import "./MarketMathCore.sol";

struct ApproxParams {
    uint256 guessMin;
    uint256 guessMax;
    uint256 maxIteration;
    uint256 eps;
}

// solhint-disable reason-string, ordering
library MarketApproxLib {
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;
    using MarketMathCore for MarketState;

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
        /// SET UP VAIRBALES
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

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }
            uint256 ptInGuess = (approx.guessMin + approx.guessMax) / 2;

            /// ------------------------------------------------------------
            /// CHECK SLOPE
            /// ------------------------------------------------------------
            (isSlopeNonNeg, largestGoodSlope) = updateSlope(
                market.totalPt,
                ptInGuess,
                comp,
                largestGoodSlope
            );
            if (!isSlopeNonNeg) {
                approx.guessMax = ptInGuess;
                continue;
            }

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, ptInGuess.neg());
            uint256 netAssetOut = _assetToAccount.Uint();

            if (netAssetOut >= minAssetOut) {
                approx.guessMax = ptInGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isAGreaterApproxB(netAssetOut, minAssetOut, approx.eps)) {
                    return (ptInGuess, index.assetToScy(netAssetOut));
                }
            } else {
                approx.guessMin = ptInGuess + 1;
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

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }
            uint256 ptOutGuess = (approx.guessMin + approx.guessMax + 1) / 2;

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

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }

            SlotSwapExactScyForYt memory slot;
            // ytOutGuess = ptInGuess
            slot.ptInGuess = (approx.guessMin + approx.guessMax + 1) / 2;

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
        require(minScyOut > 0, "invalid maxScyIn");
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

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }
            // ytInGuess = ptOutGuess
            uint256 ptOutGuess = (approx.guessMin + approx.guessMax) / 2;

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

        int256 part1 = (otToMarket * (totalPt + comp.totalAsset)).divDown(
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
        // TODO: 999 & 1000 are magic numbers
        return (maxPtOut.Uint() * 999) / 1000;
    }

    function calcMaxPtIn(int256 totalPt, int256 totalAsset) internal pure returns (uint256) {
        return Math.min(totalPt, totalAsset).Uint() - 1;
    }

    function isValidApproxParams(ApproxParams memory approx) internal pure returns (bool) {
        return (approx.guessMin <= approx.guessMax &&
            approx.maxIteration <= 256 &&
            approx.eps <= Math.ONE);
    }
}
