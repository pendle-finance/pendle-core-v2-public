// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./Math.sol";
import "./MarketMathCore.sol";
import "./MarketApproxLib.sol";

// solhint-disable reason-string, ordering
library MarketAddSingleLib {
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;
    using MarketMathCore for MarketState;

    struct SlotAddLiquiditySingle {
        uint256 ptInGuess;
        int256 _assetToAccount;
        uint256 ptToAdd;
        uint256 expectedScyAmount;
        uint256 actualScyAmount;
    }

    /**
     * @dev This function will always choose to have dust PT instead of dust SCY.
     * @dev It is always possible to swap to a smaller amount of SCY than exepected, but not in reverse.
     */
    function approxAddSingleLiquidityPT(
        MarketState memory market,
        SCYIndex index,
        uint256 ptIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256 /*ptToSwap*/
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(ptIn > 0, "invalid ptIn");
        require(MarketApproxLib.isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VARIABLES
        /// ------------------------------------------------------------
        uint256 largestGoodSlope;
        bool isSlopeNonNeg;

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = MarketApproxLib.calcMaxPtIn(market.totalPt, comp.totalAsset);
            if (approx.guessMax > ptIn) {
                approx.guessMax = ptIn;
            }
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // ++iter at end of loop

            SlotAddLiquiditySingle memory slot;

            slot.ptInGuess = MarketApproxLib.getCurrentGuess(iter, approx);
            slot.ptToAdd = ptIn - slot.ptInGuess;
            slot.expectedScyAmount =
                (slot.ptToAdd * market.totalScy.Uint()) /
                market.totalPt.Uint();

            /// ------------------------------------------------------------
            /// CHECK SLOPE
            /// ------------------------------------------------------------
            (isSlopeNonNeg, largestGoodSlope) = MarketApproxLib.updateSlope(
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
            slot.actualScyAmount = index.assetToScy(slot._assetToAccount.Uint());

            if (slot.actualScyAmount <= slot.expectedScyAmount) {
                approx.guessMin = slot.ptInGuess;
                /// ------------------------------------------------------------
                /// CHECK IF ANSWER FOUND
                /// ------------------------------------------------------------
                if (
                    Math.isASmallerApproxB(
                        slot.actualScyAmount,
                        slot.expectedScyAmount,
                        approx.eps
                    )
                ) {
                    return slot.ptInGuess;
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

    /**
     * @dev Unlike single PT one, this function will always choose to have dust SCY instead of dust PT.
     */
    function approxAddSingleLiquiditySCY(
        MarketState memory market,
        SCYIndex index,
        uint256 scyIn,
        uint256 blockTime,
        ApproxParams memory approx
    )
        internal
        pure
        returns (
            uint256 /*ptToSwapTo*/
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(scyIn > 0, "invalid scyIn");
        require(MarketApproxLib.isValidApproxParams(approx), "invalid approx approx");

        /// ------------------------------------------------------------
        /// SET UP VARIABLES
        /// ------------------------------------------------------------
        uint256 largestGoodSlope;
        bool isSlopeNonNeg;

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);

        if (approx.guessMax == type(uint256).max) {
            approx.guessMax = MarketApproxLib.calcMaxPtOut(market.totalPt, comp);
        }

        /// ------------------------------------------------------------
        /// BINARY SEARCH
        /// ------------------------------------------------------------

        for (uint256 iter = 0; iter < approx.maxIteration; ) {
            // ++iter at end of loop

            SlotAddLiquiditySingle memory slot;

            slot.ptInGuess = MarketApproxLib.getCurrentGuess(iter, approx);
            slot.ptToAdd = slot.ptInGuess;
            slot.expectedScyAmount =
                (slot.ptToAdd * market.totalScy.Uint()) /
                market.totalPt.Uint();

            /// ------------------------------------------------------------
            /// CHECK SLOPE
            /// ------------------------------------------------------------
            (isSlopeNonNeg, largestGoodSlope) = MarketApproxLib.updateSlope(
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
            (slot._assetToAccount, ) = market.calcTrade(comp, slot.ptInGuess.Int());

            uint256 scyToSwap = index.assetToScy(slot._assetToAccount.neg().Uint());

            if (scyToSwap >= scyIn) {
                approx.guessMax = slot.ptInGuess - 1;
            } else {
                slot.actualScyAmount = scyIn - scyToSwap;

                if (slot.actualScyAmount >= slot.expectedScyAmount) {
                    approx.guessMin = slot.ptInGuess;
                    /// ------------------------------------------------------------
                    /// CHECK IF ANSWER FOUND
                    /// ------------------------------------------------------------
                    if (
                        Math.isAGreaterApproxB(
                            slot.actualScyAmount,
                            slot.expectedScyAmount,
                            approx.eps
                        )
                    ) {
                        return slot.ptInGuess;
                    }
                } else {
                    approx.guessMax = slot.ptInGuess - 1;
                }
            }

            unchecked {
                ++iter;
            }
        }
        revert("approx fail");
    }
}
