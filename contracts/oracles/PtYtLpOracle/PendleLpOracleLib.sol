// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendlePYOracleLib.sol";

library PendleLpOracleLib {
    using PendlePYOracleLib for IPMarket;
    using PMath for uint256;
    using PMath for int256;
    using MarketMathCore for MarketState;

    /**
      * This function returns the approximated twap rate LP/asset on market, but take into account the current rate of SY
     This is to account for special cases where underlying asset becomes insolvent and has decreasing exchangeRate
     * @param market market to get rate from
     * @param duration twap duration
     */
    function getLpToAssetRate(IPMarket market, uint32 duration) internal view returns (uint256) {
        (uint256 syIndex, uint256 pyIndex) = market.getSYandPYIndexCurrent();
        uint256 lpToAssetRateRaw = _getLpToAssetRateRaw(market, duration, pyIndex);
        if (syIndex >= pyIndex) {
            return lpToAssetRateRaw;
        } else {
            return (lpToAssetRateRaw * syIndex) / pyIndex;
        }
    }

    /**
      * This function returns the approximated twap rate LP/asset on market, but take into account the current rate of SY
     This is to account for special cases where underlying asset becomes insolvent and has decreasing exchangeRate
     * @param market market to get rate from
     * @param duration twap duration
     */
    function getLpToSyRate(IPMarket market, uint32 duration) internal view returns (uint256) {
        (uint256 syIndex, uint256 pyIndex) = market.getSYandPYIndexCurrent();
        uint256 lpToAssetRateRaw = _getLpToAssetRateRaw(market, duration, pyIndex);
        if (syIndex >= pyIndex) {
            return lpToAssetRateRaw.divDown(syIndex);
        } else {
            return lpToAssetRateRaw.divDown(pyIndex);
        }
    }

    function _getLpToAssetRateRaw(
        IPMarket market,
        uint32 duration,
        uint256 pyIndex
    ) private view returns (uint256 lpToAssetRateRaw) {
        MarketState memory state = market.readState(address(0));

        int256 totalHypotheticalAsset;
        if (state.expiry <= block.timestamp) {
            // 1 PT = 1 Asset post-expiry
            totalHypotheticalAsset = state.totalPt + PYIndexLib.syToAsset(PYIndex.wrap(pyIndex), state.totalSy);
        } else {
            MarketPreCompute memory comp = state.getMarketPreCompute(PYIndex.wrap(pyIndex), block.timestamp);

            (int256 rateOracle, int256 rateHypTrade) = _getPtRatesRaw(market, state, duration);
            int256 cParam = LogExpMath.exp(comp.rateScalar.mulDown((rateOracle - comp.rateAnchor)));

            int256 tradeSize = (cParam.mulDown(comp.totalAsset) - state.totalPt).divDown(
                PMath.IONE + cParam.divDown(rateHypTrade)
            );

            totalHypotheticalAsset =
                comp.totalAsset -
                tradeSize.divDown(rateHypTrade) +
                (state.totalPt + tradeSize).divDown(rateOracle);
        }

        lpToAssetRateRaw = totalHypotheticalAsset.divDown(state.totalLp).Uint();
    }

    function _getPtRatesRaw(
        IPMarket market,
        MarketState memory state,
        uint32 duration
    ) private view returns (int256 rateOracle, int256 rateHypTrade) {
        uint256 lnImpliedRate = market.getMarketLnImpliedRate(duration);
        uint256 timeToExpiry = state.expiry - block.timestamp;
        rateOracle = MarketMathCore._getExchangeRateFromImpliedRate(lnImpliedRate, timeToExpiry);

        int256 rateLastTrade = MarketMathCore._getExchangeRateFromImpliedRate(state.lastLnImpliedRate, timeToExpiry);
        rateHypTrade = (rateLastTrade + rateOracle) / 2;
    }
}
