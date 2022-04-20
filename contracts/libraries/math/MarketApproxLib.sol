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

    function approxSwapOtForExactScy(
        MarketState memory market,
        SCYIndex index,
        uint256 minScyOut,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netOtIn*/
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
            approx.guessMax = calcMaxOtIn(market.totalOt, comp.totalAsset);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }
            uint256 otInGuess = (approx.guessMin + approx.guessMax) / 2;

            /// ------------------------------------------------------------
            /// CHECK SLOPE
            /// ------------------------------------------------------------
            (isSlopeNonNeg, largestGoodSlope) = updateSlope(
                market.totalOt,
                otInGuess,
                comp,
                largestGoodSlope
            );
            if (!isSlopeNonNeg) {
                approx.guessMax = otInGuess;
                continue;
            }

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, otInGuess.neg());
            uint256 netAssetOut = _assetToAccount.Uint();

            if (netAssetOut >= minAssetOut) {
                approx.guessMax = otInGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isAGreaterApproxB(netAssetOut, minAssetOut, approx.eps)) {
                    return (otInGuess, index.assetToScy(netAssetOut));
                }
            } else {
                approx.guessMin = otInGuess + 1;
            }
        }
        revert("approx fail");
    }

    function approxSwapExactScyForOt(
        MarketState memory market,
        SCYIndex index,
        uint256 maxScyIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256, /*netOtOut*/
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
            approx.guessMax = calcMaxOtOut(market.totalOt, comp);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }
            uint256 otOutGuess = (approx.guessMin + approx.guessMax + 1) / 2;

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, otOutGuess.Int());
            uint256 netAssetIn = _assetToAccount.neg().Uint();

            if (netAssetIn <= maxAssetIn) {
                approx.guessMin = otOutGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isASmallerApproxB(netAssetIn, maxAssetIn, approx.eps)) {
                    return (otOutGuess, index.assetToScy(netAssetIn));
                }
            } else {
                approx.guessMax = otOutGuess - 1;
            }
        }
        revert("approx fail");
    }

    struct SlotSwapExactScyForYt {
        uint256 otInGuess;
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
            approx.guessMax = calcMaxOtIn(market.totalOt, comp.totalAsset);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }

            SlotSwapExactScyForYt memory slot;
            // ytOutGuess = otInGuess
            slot.otInGuess = (approx.guessMin + approx.guessMax + 1) / 2;

            /// ------------------------------------------------------------
            /// CHECK SLOPE
            /// ------------------------------------------------------------
            (isSlopeNonNeg, largestGoodSlope) = updateSlope(
                market.totalOt,
                slot.otInGuess,
                comp,
                largestGoodSlope
            );
            if (!isSlopeNonNeg) {
                approx.guessMax = slot.otInGuess - 1;
                continue;
            }

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (slot._assetToAccount, ) = market.calcTrade(comp, slot.otInGuess.neg());
            slot.netAssetOut = slot._assetToAccount.Uint();
            slot.amountAssetNeedMore = slot.otInGuess - slot.netAssetOut;

            if (slot.amountAssetNeedMore <= maxAssetIn) {
                approx.guessMin = slot.otInGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isASmallerApproxB(slot.amountAssetNeedMore, maxAssetIn, approx.eps)) {
                    return (slot.otInGuess, index.assetToScy(slot.amountAssetNeedMore));
                }
            } else {
                approx.guessMax = slot.otInGuess - 1;
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
            approx.guessMax = calcMaxOtOut(market.totalOt, comp);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }
            // ytInGuess = otOutGuess
            uint256 otOutGuess = (approx.guessMin + approx.guessMax) / 2;

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, otOutGuess.Int());
            uint256 netAssetOwed = _assetToAccount.neg().Uint();

            // since otOutGuess is between guessMin & guessMax, it's guaranteed that
            // there are enough Yt to pair with otOut

            uint256 netAssetOut = otOutGuess - netAssetOwed;

            if (netAssetOut >= minAssetOut) {
                approx.guessMax = otOutGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (Math.isAGreaterApproxB(netAssetOut, minAssetOut, approx.eps)) {
                    return (otOutGuess, index.assetToScy(netAssetOut));
                }
            } else {
                approx.guessMin = otOutGuess + 1;
            }
        }
        revert("approx fail");
    }

    function updateSlope(
        int256 totalOt,
        uint256 otInGuess,
        MarketPreCompute memory comp,
        uint256 largestGoodSlope
    ) internal pure returns (bool isSlopeNonNeg, uint256 newLargestGoodSlop) {
        if (otInGuess <= largestGoodSlope) {
            return (true, largestGoodSlope);
        }
        // it's not guaranteed that the current slop is good
        // we therefore have to recalculate the slope
        int256 slope = slopeFactor(totalOt, otInGuess.neg(), comp);
        if (slope >= 0) return (true, otInGuess);
        else return (false, largestGoodSlope);
    }

    // otToMarket < totalAsset && totalOt
    function slopeFactor(
        int256 totalOt,
        int256 otToAccount,
        MarketPreCompute memory comp
    ) internal pure returns (int256) {
        int256 otToMarket = -otToAccount;
        int256 diffAssetOtToMarket = comp.totalAsset - otToMarket;
        int256 sumOt = otToMarket + totalOt;

        require(diffAssetOtToMarket > 0 && sumOt > 0, "invalid otToMarket");

        int256 part1 = (otToMarket * (totalOt + comp.totalAsset)).divDown(
            sumOt * diffAssetOtToMarket
        );

        int256 part2 = sumOt.divDown(diffAssetOtToMarket).ln();
        int256 part3 = Math.IONE.divDown(comp.rateScalar);

        return comp.rateAnchor - (part1 - part2).mulDown(part3);
    }

    function calcMaxOtOut(int256 totalOt, MarketPreCompute memory comp)
        internal
        pure
        returns (uint256)
    {
        int256 logitP = (Math.IONE.mulDown(comp.lnFeeRate) - comp.rateAnchor)
            .mulDown(comp.rateScalar)
            .exp();
        int256 proportion = logitP.divDown(logitP + Math.IONE);
        int256 numerator = proportion.mulDown(totalOt + comp.totalAsset);
        int256 maxOtOut = totalOt - numerator;
        // TODO: 999 & 1000 are magic numbers
        return (maxOtOut.Uint() * 999) / 1000;
    }

    function calcMaxOtIn(int256 totalOt, int256 totalAsset) internal pure returns (uint256) {
        return Math.min(totalOt, totalAsset).Uint() - 1;
    }

    function isValidApproxParams(ApproxParams memory approx) internal pure returns (bool) {
        return (approx.guessMin <= approx.guessMax &&
            approx.maxIteration <= 256 &&
            approx.eps <= Math.ONE);
    }
}
