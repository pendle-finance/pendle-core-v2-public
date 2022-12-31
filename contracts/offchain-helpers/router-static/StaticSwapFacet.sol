// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../MarketMathStatic.sol";
import "./StaticMintRedeemFacet.sol";

contract StaticSwapFacet is StaticMintRedeemFacet {
    function swapExactPtForSyStatic(address market, uint256 exactPtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapExactPtForSyStatic(market, exactPtIn);
    }

    function swapSyForExactPtStatic(address market, uint256 exactPtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapSyForExactPtStatic(market, exactPtOut);
    }

    function swapExactSyForPtStatic(address market, uint256 exactSyIn)
        public
        returns (
            uint256 netPtOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapExactSyForPtStatic(market, exactSyIn);
    }

    function swapPtForExactSyStatic(address market, uint256 exactSyOut)
        public
        returns (
            uint256 netPtIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapPtForExactSyStatic(market, exactSyOut);
    }

    function swapExactBaseTokenForPtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken,
        address bulk
    )
        external
        returns (
            uint256 netPtOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        uint256 netSyIn = previewDepositStatic(
            getSyMarket(market),
            baseToken,
            amountBaseToken,
            bulk
        );
        return MarketMathStatic.swapExactSyForPtStatic(market, netSyIn);
    }

    function swapExactPtForBaseTokenStatic(
        address market,
        uint256 exactPtIn,
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
            .swapExactPtForSyStatic(market, exactPtIn);

        netBaseTokenOut = previewRedeemStatic(getSyMarket(market), baseToken, netSyOut, bulk);
    }

    function swapSyForExactYtStatic(address market, uint256 exactYtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapSyForExactYtStatic(market, exactYtOut);
    }

    function swapExactSyForYtStatic(address market, uint256 exactSyIn)
        public
        returns (
            uint256 netYtOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapExactSyForYtStatic(market, exactSyIn);
    }

    function swapExactYtForSyStatic(address market, uint256 exactYtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapExactYtForSyStatic(market, exactYtIn);
    }

    function swapYtForExactSyStatic(address market, uint256 exactSyOut)
        external
        returns (
            uint256 netYtIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapYtForExactSyStatic(market, exactSyOut);
    }

    function swapExactYtForBaseTokenStatic(
        address market,
        uint256 exactYtIn,
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
            .swapExactYtForSyStatic(market, exactYtIn);

        netBaseTokenOut = previewRedeemStatic(getSyMarket(market), baseToken, netSyOut, bulk);
    }

    function swapExactBaseTokenForYtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken,
        address bulk
    )
        external
        returns (
            uint256 netYtOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        uint256 netSyIn = previewDepositStatic(
            getSyMarket(market),
            baseToken,
            amountBaseToken,
            bulk
        );

        return MarketMathStatic.swapExactSyForYtStatic(market, netSyIn);
    }

    function swapExactPtForYtStatic(address market, uint256 exactPtIn)
        external
        returns (
            uint256 netYtOut,
            uint256 totalPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapExactPtForYt(market, exactPtIn);
    }

    function swapExactYtForPtStatic(address market, uint256 exactYtIn)
        external
        returns (
            uint256 netPtOut,
            uint256 totalPtSwapped,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        return MarketMathStatic.swapExactYtForPt(market, exactYtIn);
    }

    function getSyMarket(address market) public view returns (IStandardizedYield) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        return SY;
    }
}