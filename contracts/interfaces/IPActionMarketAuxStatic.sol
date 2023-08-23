pragma solidity ^0.8.0;

import "./IPMarket.sol";

interface IPActionMarketAuxStatic {
    function calcPriceImpactPY(address market, int256 netPtOut) external view returns (uint256);

    function calcPriceImpactPt(address market, int256 netPtOut) external view returns (uint256);

    function calcPriceImpactYt(address market, int256 netPtOut) external view returns (uint256);

    function getMarketState(address market)
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

    function getTradeExchangeRateExcludeFee(address market, MarketState memory state)
        external
        view
        returns (uint256);

    function getTradeExchangeRateIncludeFee(address market, int256 netPtOut)
        external
        view
        returns (uint256);

    function getLpToSyRate(address market) external view returns (uint256);

    function getPtToSyRate(address market) external view returns (uint256);

    function getLpToAssetRate(address market) external view returns (uint256);

    function getPtToAssetRate(address market) external view returns (uint256);
}
