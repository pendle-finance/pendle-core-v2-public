// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPRouterStatic.sol";
import "./StorageLayout.sol";

contract ActionMarketAuxStatic is IPActionMarketAuxStatic {
    using MarketMathCore for MarketState;
    using Math for int256;
    using Math for uint256;
    using LogExpMath for int256;
    using PYIndexLib for PYIndex;
    using PYIndexLib for IPYieldToken;

    function getMarketState(
        address market
    )
        public
        returns (
            address pt,
            address yt,
            address sy,
            int256 impliedYield,
            uint256 marketExchangeRateExcludeFee,
            MarketState memory state
        )
    {
        (IStandardizedYield SY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market)
            .readTokens();

        pt = address(PT);
        yt = address(YT);
        sy = address(SY);
        state = _readState(market);
        impliedYield = _getPtImpliedYield(market);
        marketExchangeRateExcludeFee = getTradeExchangeRateExcludeFee(market, state);
    }

    function getTradeExchangeRateExcludeFee(
        address market,
        MarketState memory state
    ) public returns (uint256) {
        if (IPMarket(market).isExpired()) return Math.ONE;

        MarketPreCompute memory comp = state.getMarketPreCompute(
            _pyIndex(market),
            block.timestamp
        );
        int256 preFeeExchangeRate = MarketMathCore._getExchangeRate(
            state.totalPt,
            comp.totalAsset,
            comp.rateScalar,
            comp.rateAnchor,
            0
        );
        return preFeeExchangeRate.Uint();
    }

    function getTradeExchangeRateIncludeFee(
        address market,
        int256 netPtOut
    ) public returns (uint256) {
        if (IPMarket(market).isExpired()) return Math.ONE;

        int256 netPtToAccount = netPtOut;
        MarketState memory state = _readState(market);
        MarketPreCompute memory comp = state.getMarketPreCompute(
            _pyIndex(market),
            block.timestamp
        );

        int256 preFeeExchangeRate = MarketMathCore._getExchangeRate(
            state.totalPt,
            comp.totalAsset,
            comp.rateScalar,
            comp.rateAnchor,
            netPtToAccount
        );

        if (netPtToAccount > 0) {
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(comp.feeRate);
            if (postFeeExchangeRate < Math.IONE)
                revert Errors.MarketExchangeRateBelowOne(postFeeExchangeRate);
            return postFeeExchangeRate.Uint();
        } else {
            return preFeeExchangeRate.mulDown(comp.feeRate).Uint();
        }
    }

    function calcPriceImpactPt(
        address market,
        int256 netPtOut
    ) public returns (uint256 priceImpact) {
        uint256 preTradeRate = getTradeExchangeRateIncludeFee(market, _getSign(netPtOut));
        uint256 tradedRate = getTradeExchangeRateIncludeFee(market, netPtOut);
        priceImpact = _calculateImpact(preTradeRate, tradedRate);
    }

    function calcPriceImpactYt(
        address market,
        int256 netPtOut
    ) public returns (uint256 priceImpact) {
        uint256 ytPreTradeRate = _calcVirtualYTPrice(
            getTradeExchangeRateIncludeFee(market, _getSign(netPtOut))
        );
        uint256 ytTradedRate = _calcVirtualYTPrice(
            getTradeExchangeRateIncludeFee(market, netPtOut)
        );
        priceImpact = _calculateImpact(ytPreTradeRate, ytTradedRate);
    }

    function calcPriceImpactPY(
        address market,
        int256 netPtOut
    ) public returns (uint256 priceImpact) {
        uint256 ptPreTradeRate = getTradeExchangeRateIncludeFee(market, _getSign(netPtOut));
        uint256 ytPreTradeRate = _calcVirtualYTPrice(ptPreTradeRate);
        uint256 ptTradeRate = getTradeExchangeRateIncludeFee(market, netPtOut);
        uint256 ytTradeRate = _calcVirtualYTPrice(ptTradeRate);

        uint256 pyPreTradeRate = ytPreTradeRate.divDown(ptPreTradeRate);
        uint256 pyTradeRate = ytTradeRate.divDown(ptTradeRate);
        priceImpact = _calculateImpact(pyPreTradeRate, pyTradeRate);
    }

    function _getPtImpliedYield(address market) internal view returns (int256) {
        MarketState memory state = _readState(market);

        int256 lnImpliedRate = (state.lastLnImpliedRate).Int();
        return lnImpliedRate.exp();
    }

    function _calcVirtualYTPrice(
        uint256 ptAssetExchangeRate
    ) private pure returns (uint256 ytAssetExchangeRate) {
        // 1 asset = EX pt
        // 1 pt = 1/EX Asset
        // 1 yt + 1/EX Asset = 1 Asset
        // 1 yt = 1 Asset - 1/EX Asset
        // 1 yt = (EX - 1) / EX Asset
        return (ptAssetExchangeRate - Math.ONE).divDown(ptAssetExchangeRate);
    }

    function _readState(address market) internal view returns (MarketState memory) {
        return IPMarket(market).readState(address(this));
    }

    function _getSign(int256 netPtOut) private pure returns (int256) {
        return netPtOut > 0 ? int256(1) : int256(-1);
    }

    function _calculateImpact(
        uint256 rateBefore,
        uint256 rateTraded
    ) private pure returns (uint256 impact) {
        impact = (rateBefore.Int() - rateTraded.Int()).abs().divDown(rateBefore);
    }

    function _pyIndex(address market) internal returns (PYIndex index) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        return YT.newIndex();
    }
}
