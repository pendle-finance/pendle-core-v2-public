// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../MarketMathStatic.sol";
import "./StaticMintRedeemFacet.sol";

contract StaticAddRemoveLiqFacet is StaticMintRedeemFacet {
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
            uint256 netPtUsed
        )
    {
        uint256 netSyDesired = previewDepositStatic(
            getSyMarket(market),
            tokenIn,
            netTokenDesired,
            bulk
        );

        uint256 netSyUsed;
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
            uint256 exchangeRateAfter
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
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.addLiquiditySingleSyStatic(market, netSyIn);
    }

    function addLiquiditySingleBaseTokenStatic(
        address market,
        address baseToken,
        uint256 netBaseTokenIn,
        address bulk
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        uint256 netSyIn = previewDepositStatic(
            getSyMarket(market),
            baseToken,
            netBaseTokenIn,
            bulk
        );

        return MarketMathStatic.addLiquiditySingleSyStatic(market, netSyIn);
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
    ) external view returns (uint256 netTokenOut, uint256 netPtOut) {
        uint256 netSyOut;

        (netSyOut, netPtOut) = MarketMathStatic.removeLiquidityDualSyAndPtStatic(
            market,
            netLpToRemove
        );

        netTokenOut = previewRedeemStatic(getSyMarket(market), tokenOut, netSyOut, bulk);
    }

    function removeLiquiditySinglePtStatic(address market, uint256 netLpToRemove)
        external
        returns (
            uint256 netPtOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
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
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.removeLiquiditySingleSyStatic(market, netLpToRemove);
    }

    function removeLiquiditySingleBaseTokenStatic(
        address market,
        uint256 netLpToRemove,
        address baseToken,
        address bulk
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        uint256 netSyOut;

        (netSyOut, netSyFee, priceImpact, exchangeRateAfter) = MarketMathStatic
            .removeLiquiditySingleSyStatic(market, netLpToRemove);

        netBaseTokenOut = previewRedeemStatic(getSyMarket(market), baseToken, netSyOut, bulk);
    }

    function getSyMarket(address market) public view returns (IStandardizedYield) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        return SY;
    }
}