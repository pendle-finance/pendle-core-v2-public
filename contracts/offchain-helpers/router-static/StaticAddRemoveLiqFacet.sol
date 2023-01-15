// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../MarketMathStatic.sol";
import "./StaticMintRedeemFacet.sol";

contract StaticAddRemoveLiqFacet {
    function addLiquidityDualSyAndPtStatic(
        address market,
        uint256 netSyDesired,
        uint256 netPtDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netSyUsed,
            uint256 netPtUsed
        )
    {
        return MarketMathStatic.addLiquidityDualSyAndPtStatic(market, netSyDesired, netPtDesired);
    }

    function addLiquidityDualTokenAndPtStatic(
        address market,
        address tokenIn,
        uint256 netTokenDesired,
        address bulk,
        uint256 netPtDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netTokenUsed,
            uint256 netPtUsed,
            uint256 netSyUsed
        )
    {
        uint256 netSyDesired = StaticMintRedeemFacet(address(this)).previewDepositStatic(
            getSyMarket(market),
            tokenIn,
            netTokenDesired,
            bulk
        );

        (netLpOut, netSyUsed, netPtUsed) = MarketMathStatic.addLiquidityDualSyAndPtStatic(
            market,
            netSyDesired,
            netPtDesired
        );

        if (netSyUsed != netSyDesired) revert Errors.RouterNotAllSyUsed(netSyDesired, netSyUsed);

        netTokenUsed = netTokenDesired;
    }

    function addLiquiditySinglePtStatic(address market, uint256 netPtIn)
        external
        returns (
            uint256 netLpOut,
            uint256 netPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        return MarketMathStatic.addLiquiditySinglePtStatic(market, netPtIn);
    }

    function addLiquiditySingleSyStatic(address market, uint256 netSyIn)
        public
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        return MarketMathStatic.addLiquiditySingleSyStatic(market, netSyIn);
    }

    function addLiquiditySingleTokenInStatic(
        address market,
        address tokenIn,
        uint256 netTokenIn,
        address bulk
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        netSyMinted = StaticMintRedeemFacet(address(this)).previewDepositStatic(
            getSyMarket(market),
            tokenIn,
            netTokenIn,
            bulk
        );
        (
            netLpOut,
            netPtFromSwap,
            netSyFee,
            priceImpact,
            tradeExchangeRateExcludeFeeAfter
        ) = MarketMathStatic.addLiquiditySingleSyStatic(market, netSyMinted);
    }

    function removeLiquidityDualSyAndPtStatic(address market, uint256 netLpToRemove)
        external
        view
        returns (uint256 netSyOut, uint256 netPtOut)
    {
        return MarketMathStatic.removeLiquidityDualSyAndPtStatic(market, netLpToRemove);
    }

    function removeLiquidityDualTokenAndPtStatic(
        address market,
        uint256 netLpToRemove,
        address tokenOut,
        address bulk
    )
        external
        view
        returns (
            uint256 netTokenOut,
            uint256 netPtOut,
            uint256 netSyToRedeem
        )
    {
        (netSyToRedeem, netPtOut) = MarketMathStatic.removeLiquidityDualSyAndPtStatic(
            market,
            netLpToRemove
        );

        netTokenOut = StaticMintRedeemFacet(address(this)).previewRedeemStatic(
            getSyMarket(market),
            tokenOut,
            netSyToRedeem,
            bulk
        );
    }

    function removeLiquiditySinglePtStatic(address market, uint256 netLpToRemove)
        external
        returns (
            uint256 netPtOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        return MarketMathStatic.removeLiquiditySinglePtStatic(market, netLpToRemove);
    }

    function removeLiquiditySingleSyStatic(address market, uint256 netLpToRemove)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        return MarketMathStatic.removeLiquiditySingleSyStatic(market, netLpToRemove);
    }

    function removeLiquiditySingleTokenOutStatic(
        address market,
        uint256 netLpToRemove,
        address tokenOut,
        address bulk
    )
        external
        returns (
            uint256 netTokenOut,
            uint256 netSyToRedeem,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        (netSyToRedeem, netSyFee, priceImpact, tradeExchangeRateExcludeFeeAfter) = MarketMathStatic
            .removeLiquiditySingleSyStatic(market, netLpToRemove);

        netTokenOut = StaticMintRedeemFacet(address(this)).previewRedeemStatic(
            getSyMarket(market),
            tokenOut,
            netSyToRedeem,
            bulk
        );
    }

    function getSyMarket(address market) public view returns (IStandardizedYield) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        return SY;
    }
}
