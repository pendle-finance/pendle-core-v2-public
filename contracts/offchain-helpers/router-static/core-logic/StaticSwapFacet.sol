// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../MarketMathStatic.sol";
import "./StaticMintRedeemFacet.sol";

contract StaticSwapFacet {
    function swapExactPtForSyStatic(address market, uint256 exactPtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
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
            uint256 tradeExchangeRateExcludeFeeAfter
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
            uint256 tradeExchangeRateExcludeFeeAfter
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
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        return MarketMathStatic.swapPtForExactSyStatic(market, exactSyOut);
    }

    function swapExactTokenInForPtStatic(
        address market,
        address tokenIn,
        uint256 amountTokenIn,
        address bulk
    )
        external
        returns (
            uint256 netPtOut,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        netSyMinted = StaticMintRedeemFacet(address(this)).previewDepositStatic(
            getSyMarket(market),
            tokenIn,
            amountTokenIn,
            bulk
        );
        (netPtOut, netSyFee, priceImpact, tradeExchangeRateExcludeFeeAfter) = MarketMathStatic
            .swapExactSyForPtStatic(market, netSyMinted);
    }

    function swapExactPtForTokenOutStatic(
        address market,
        uint256 exactPtIn,
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
            .swapExactPtForSyStatic(market, exactPtIn);

        netTokenOut = StaticMintRedeemFacet(address(this)).previewRedeemStatic(
            getSyMarket(market),
            tokenOut,
            netSyToRedeem,
            bulk
        );
    }

    function swapSyForExactYtStatic(address market, uint256 exactYtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
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
            uint256 tradeExchangeRateExcludeFeeAfter
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
            uint256 tradeExchangeRateExcludeFeeAfter
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
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        return MarketMathStatic.swapYtForExactSyStatic(market, exactSyOut);
    }

    function swapExactYtForTokenOutStatic(
        address market,
        uint256 exactYtIn,
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
            .swapExactYtForSyStatic(market, exactYtIn);

        netTokenOut = StaticMintRedeemFacet(address(this)).previewRedeemStatic(
            getSyMarket(market),
            tokenOut,
            netSyToRedeem,
            bulk
        );
    }

    function swapExactTokenInForYtStatic(
        address market,
        address tokenIn,
        uint256 amountTokenIn,
        address bulk
    )
        external
        returns (
            uint256 netYtOut,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        netSyMinted = StaticMintRedeemFacet(address(this)).previewDepositStatic(
            getSyMarket(market),
            tokenIn,
            amountTokenIn,
            bulk
        );
        (netYtOut, netSyFee, priceImpact, tradeExchangeRateExcludeFeeAfter) = MarketMathStatic
            .swapExactSyForYtStatic(market, netSyMinted);
    }

    function swapExactPtForYtStatic(address market, uint256 exactPtIn)
        external
        returns (
            uint256 netYtOut,
            uint256 totalPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 tradeExchangeRateExcludeFeeAfter
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
            uint256 tradeExchangeRateExcludeFeeAfter
        )
    {
        return MarketMathStatic.swapExactYtForPt(market, exactYtIn);
    }

    function getSyMarket(address market) public view returns (IStandardizedYield) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        return SY;
    }
}
