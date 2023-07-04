// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./PendlePtOracleLib.sol";

// Reference: https://file.notion.so/f/s/15d1406b-0d81-41a4-8ac3-9b56e30fdf50/LP_Oracle_Doc.pdf?id=201fc56f-959b-4836-9511-73852e166816&table=block&spaceId=33abd05a-56a2-4ce6-8673-929c5984a0fd&expirationTimestamp=1683863581610&signature=IY3jlxvXkWRJZhsccYpQdQaKlm1_NUIb1ypDmuaR7hI&downloadName=LP_Oracle_Doc.pdf

library PendleLpOracleLib {
    using PendlePtOracleLib for IPMarket;
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;

    /**
      * This function returns the approximated twap rate LP/asset on market, but take into account the current rate of SY
     This is to account for special cases where underlying asset becomes insolvent and has decreasing exchangeRate
     * @param market market to get rate from
     * @param duration twap duration
     */
    function getLpToAssetRate(IPMarket market, uint32 duration) internal view returns (uint256) {
        (uint256 syIndex, uint256 pyIndex) = PendlePtOracleLib.getSYandPYIndexCurrent(market);
        uint256 lpToAssetRateRaw = _getLpToAssetRateRaw(market, duration, pyIndex);
        return (lpToAssetRateRaw * syIndex) / pyIndex;
    }

    function _getLpToAssetRateRaw(
        IPMarket market,
        uint32 duration,
        uint256 pyIndex
    ) private view returns (uint256 lpToAssetRateRaw) {
        MarketState memory state = market.readState(address(0));

        MarketPreCompute memory comp = state.getMarketPreCompute(
            PYIndex.wrap(pyIndex),
            block.timestamp
        );

        int256 totalHypotheticalAsset;
        if (state.expiry <= block.timestamp) {
            // 1 PT = 1 Asset post-expiry
            totalHypotheticalAsset = state.totalPt + comp.totalAsset;
        } else {
            (int256 rateOracle, int256 rateHypTrade) = _getPtRatesRaw(market, state, duration);
            int256 cParam = LogExpMath.exp(
                comp.rateScalar.mulDown((rateOracle - comp.rateAnchor))
            );

            int256 tradeSize = (cParam.mulDown(comp.totalAsset) - state.totalPt).divDown(
                Math.IONE + cParam.divDown(rateHypTrade)
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
        rateOracle = Math.IONE.divDown(market.getPtToAssetRateRaw(duration).Int());
        int256 rateLastTrade = MarketMathCore._getExchangeRateFromImpliedRate(
            state.lastLnImpliedRate,
            state.expiry - block.timestamp
        );
        rateHypTrade = (rateLastTrade + rateOracle) / 2;
    }
}
