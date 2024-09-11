// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {MarketMathCore, MarketState} from "../../core/Market/MarketMathCore.sol";
import {PYIndexLib, PYIndex} from "../../core/StandardizedYield/PYIndex.sol";
import {PMath} from "../../core/libraries/math/PMath.sol";

library MarketApproxEstimateLib {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;

    enum TokenType {
        PT,
        YT,
        SY
    }

    function estimateAmount(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime,
        uint256 amountIn,
        TokenType tokenIn,
        TokenType tokenOut
    ) internal pure returns (uint256 estimatedAmountOut) {
        uint256 assetToPtRate = uint256(
            MarketMathCore._getExchangeRateFromImpliedRate(market.lastLnImpliedRate, market.expiry - blockTime)
        );

        uint256 ptToAssetRate = PMath.ONE.divDown(assetToPtRate);
        uint256 ytToAssetRate = PMath.ONE - ptToAssetRate;

        uint256 exactAssetIn;

        if (tokenIn == TokenType.SY) {
            exactAssetIn = index.syToAsset(amountIn);
        } else if (tokenIn == TokenType.PT) {
            exactAssetIn = amountIn.mulDown(ptToAssetRate);
        } else {
            exactAssetIn = amountIn.mulDown(ytToAssetRate);
        }

        if (tokenOut == TokenType.SY) {
            estimatedAmountOut = index.assetToSy(exactAssetIn);
        } else if (tokenOut == TokenType.PT) {
            estimatedAmountOut = exactAssetIn.divDown(ptToAssetRate);
        } else {
            estimatedAmountOut = exactAssetIn.divDown(ytToAssetRate);
        }
    }

    function estimateSwapExactSyForPt(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime,
        uint256 amountSyIn
    ) internal pure returns (uint256 estimatedPtOut) {
        return estimateAmount(market, index, blockTime, amountSyIn, TokenType.SY, TokenType.PT);
    }

    function estimateSwapExactSyForYt(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime,
        uint256 amountSyIn
    ) internal pure returns (uint256 estimatedYtOut) {
        return estimateAmount(market, index, blockTime, amountSyIn, TokenType.SY, TokenType.YT);
    }

    function estimateAddLiquidity(
        MarketState memory market,
        PYIndex index,
        uint256 blockTime,
        uint256 netPtOwning,
        uint256 netSyOwning
    ) internal pure returns (uint256 estimatedPtToAdd, uint256 estimatedSyToAdd) {
        // Let `pa` be `estimatedPtToAdd`, `sa` be `estimatedSyToAdd`.

        // Conditions to satisfy:
        // +) Add liquidity amounts need to be proportional to the existing
        //    liquidity:
        //      pa / sa = totalPt / totalSy
        //   => pa = totalPt / totalSy * sa
        //
        // +) Let `syToPtRate` be the spot price between the PT and SY amount.
        //    Conversion between exessive/missing parts need to respect the
        //    current price:
        //      (sa - netSyOwning) * syToPtRate = netPtOwning - pa
        //  <=> (sa - netSyOwning) * syToPtRate = netPtOwning - totalPt / totalSy * sa
        //  <=> (sa - netSyOwning) * syToPtRate * totalSy = netPtOwning * totalSy - totalPt * sa
        //
        //  Let x = syToPtRate * totalSy (x can be calculated with the function `estimateAmount` above).
        //      (sa - netSyOwning) * x = netPtOwning * totalSy - totalPt * sa
        //  <=> sa * x - netSyOwning * x = netPtOwning * totalSy - totalPt * sa
        //  <=> sa * (x + totalPt) = netPtOwning * totalSy + netSyOwning * x

        uint256 totalSy = market.totalSy.Uint();
        uint256 totalPt = market.totalPt.Uint();
        uint256 x = estimateSwapExactSyForPt(market, index, blockTime, totalSy);
        uint256 sa = (netPtOwning * totalSy + netSyOwning * x) / (x + totalPt);
        uint256 pa = (totalPt * sa) / totalSy;

        return (pa, sa);
    }
}
