// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./FixedPoint.sol";
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
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;
    using MarketMathCore for MarketState;

    /// @param approx the 4 variables in the struct will be used as follows:
    /// guessMin & guessMax: the range to search for netOtIn
    /// eps: this guarantees netScyOut <= minScyOut * (1 + eps)
    /// maxIteration: the binary search will be done no more than this number of times. Each runs
    /// takes about 6k or 12k gas (12k gas only when guessMax is extremely big)
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

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = FixedPoint.min(comp.totalAsset, market.totalOt).Uint() - 1;
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
            if (otInGuess > largestGoodSlope) {
                // it's not guaranteed that the current slop is good
                // we therefore have to recalculate the slope
                int256 slope = slopeFactor(
                    market.totalOt,
                    comp.rateScalar,
                    comp.totalAsset,
                    comp.rateAnchor,
                    otInGuess.neg()
                );

                if (slope < 0) {
                    approx.guessMax = otInGuess;
                    continue;
                } else {
                    largestGoodSlope = otInGuess;
                }
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
                if (netAssetOut <= minAssetOut.mulDown(FixedPoint.ONE + approx.eps)) {
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
            int256 logitP = (FixedPoint.IONE.mulDown(comp.feeRate) - comp.rateAnchor)
                .mulDown(comp.rateScalar)
                .exp();
            int256 proportion = logitP.divDown(logitP + FixedPoint.IONE);
            int256 numerator = proportion.mulDown(market.totalOt + comp.totalAsset);
            int256 maxOtOut = market.totalOt - numerator;
            // TODO: 999 & 1000 are magic numbers
            approx.guessMax = (maxOtOut.Uint() * 999) / 1000;
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
                if (netAssetIn >= maxAssetIn.mulDown(FixedPoint.ONE - approx.eps)) {
                    return (otOutGuess, index.assetToScy(netAssetIn));
                }
            } else {
                approx.guessMax = otOutGuess - 1;
            }
        }
        revert("approx fail");
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

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = FixedPoint.min(comp.totalAsset, market.totalOt).Uint() - 1;
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        while (approx.maxIteration != 0) {
            unchecked {
                approx.maxIteration--;
            }
            // ytOutGuess = otInGuess
            uint256 otInGuess = (approx.guessMin + approx.guessMax) / 2;

            /// ------------------------------------------------------------
            /// CHECK SLOPE
            /// ------------------------------------------------------------
            if (otInGuess > largestGoodSlope) {
                // it's not guaranteed that the current slop is good
                // we therefore have to recalculate the slope
                int256 slope = slopeFactor(
                    market.totalOt,
                    comp.rateScalar,
                    comp.totalAsset,
                    comp.rateAnchor,
                    otInGuess.neg()
                );

                if (slope < 0) {
                    approx.guessMax = otInGuess - 1;
                    continue;
                } else {
                    largestGoodSlope = otInGuess;
                }
            }

            /// ------------------------------------------------------------
            /// CHECK ASSET
            /// ------------------------------------------------------------
            (int256 _assetToAccount, ) = market.calcTrade(comp, otInGuess.neg());
            uint256 netAssetOut = _assetToAccount.Uint();
            uint256 amountAssetNeedMore = otInGuess - netAssetOut;

            if (amountAssetNeedMore <= maxAssetIn) {
                approx.guessMin = otInGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (amountAssetNeedMore >= maxAssetIn.mulDown(FixedPoint.ONE - approx.eps)) {
                    return (otInGuess, index.assetToScy(amountAssetNeedMore));
                }
            } else {
                approx.guessMax = otInGuess - 1;
            }
        }
        revert("approx fail");
    }

    // otToMarket < totalAsset && totalOt
    function slopeFactor(
        int256 totalOt,
        int256 rateScalar,
        int256 totalAsset,
        int256 rateAnchor,
        int256 otToAccount
    ) internal pure returns (int256) {
        int256 otToMarket = -otToAccount;
        int256 diffAssetOtToMarket = totalAsset - otToMarket;
        int256 sumOt = otToMarket + totalOt;

        require(diffAssetOtToMarket > 0 && sumOt > 0, "invalid otToMarket");

        int256 part1 = (otToMarket * (totalOt + totalAsset)).divDown(sumOt * diffAssetOtToMarket);

        int256 part2 = sumOt.divDown(diffAssetOtToMarket).ln();
        int256 part3 = FixedPoint.IONE.divDown(rateScalar);

        return rateAnchor - (part1 - part2).mulDown(part3);
    }

    function isValidApproxParams(ApproxParams memory approx) internal pure returns (bool) {
        return (approx.guessMin <= approx.guessMax &&
            approx.maxIteration <= 256 &&
            approx.eps <= FixedPoint.ONE);
    }
}
