pragma solidity ^0.8.0;

import "./IPMarket.sol";
import {ApproxParams} from "../router/base/MarketApproxLib.sol";

interface IPActionMarketAuxStatic {
    function calcPriceImpactPY(address market, int256 netPtOut) external view returns (uint256);

    function calcPriceImpactPt(address market, int256 netPtOut) external view returns (uint256);

    function calcPriceImpactYt(address market, int256 netPtOut) external view returns (uint256);

    function getMarketState(
        address market
    )
        external
        view
        returns (
            address pt,
            address yt,
            address sy,
            int256 impliedYield,
            uint256 marketExchangeRateExcludeFee,
            MarketState memory state
        );

    function getTradeExchangeRateExcludeFee(address market, MarketState memory state) external view returns (uint256);

    function getTradeExchangeRateIncludeFee(address market, int256 netPtOut) external view returns (uint256);

    function getYieldTokenAndPtRate(
        address market
    ) external view returns (address yieldToken, uint256 netPtOut, uint256 netYieldTokenOut);

    function getYieldTokenAndYtRate(
        address market
    ) external view returns (address yieldToken, uint256 netYtOut, uint256 netYieldTokenOut);

    function getLpToSyRate(address market) external view returns (uint256);

    function getPtToSyRate(address market) external view returns (uint256);

    function getYtToSyRate(address market) external view returns (uint256);

    function getLpToAssetRate(address market) external view returns (uint256);

    function getPtToAssetRate(address market) external view returns (uint256);

    function getYtToAssetRate(address market) external view returns (uint256);

    /// @param slippage A fixed-point number with 18 decimal places
    function swapExactSyForPtStaticAndGenerateApproxParams(
        address market,
        uint256 exactSyIn,
        uint256 slippage
    )
        external
        view
        returns (
            uint256 netPtOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            ApproxParams memory approxParams
        );

    /// @param slippage A fixed-point number with 18 decimal places
    function swapExactTokenForPtStaticAndGenerateApproxParams(
        address market,
        address tokenIn,
        uint256 amountTokenIn,
        uint256 slippage
    )
        external
        view
        returns (
            uint256 netPtOut,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            ApproxParams memory approxParams
        );
}
