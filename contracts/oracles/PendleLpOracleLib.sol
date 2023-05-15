// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./PendlePtOracleLib.sol";

// Reference: https://file.notion.so/f/s/15d1406b-0d81-41a4-8ac3-9b56e30fdf50/LP_Oracle_Doc.pdf?id=201fc56f-959b-4836-9511-73852e166816&table=block&spaceId=33abd05a-56a2-4ce6-8673-929c5984a0fd&expirationTimestamp=1683863581610&signature=IY3jlxvXkWRJZhsccYpQdQaKlm1_NUIb1ypDmuaR7hI&downloadName=LP_Oracle_Doc.pdf

library PendleLpOracleLib {
    using PendlePtOracleLib for IPMarket;
    using PYIndexLib for PYIndex;
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;

    /**
     * This function returns the approximated twap rate LP/Asset on market
     * @param market market to get rate from
     * @param duration twap duration
     *
     */
    function getLpToAssetRate(IPMarket market, uint32 duration)
        internal
        view
        returns (uint256 lpToAssetRate)
    {
        MarketState memory state = market.readState(address(0));
        MarketPreCompute memory comp = _getMarketPreCompute(market, state);

        int256 totalHypotheticalAsset;
        if (state.expiry <= block.timestamp) {
            // 1 PT = 1 Asset post-expiry
            totalHypotheticalAsset = state.totalPt + comp.totalAsset;
        } else {
            (int256 rateOracle, int256 rateLastTrade, int256 rateHypTrade) = _getPtRates(
                market,
                state,
                duration
            );
            int256 cParam = LogExpMath.exp(
                comp.rateScalar.mulDown((rateOracle - comp.rateAnchor))
            );

            int256 tradeSize = (cParam.mulDown(comp.totalAsset) - state.totalPt).divDown(
                Math.IONE + cParam.divDown(rateHypTrade)
            );

            totalHypotheticalAsset =
                comp.totalAsset -
                tradeSize.divDown(rateHypTrade) +
                (state.totalPt + tradeSize).divDown(rateLastTrade);
        }

        lpToAssetRate = _calcLpPrice(totalHypotheticalAsset, state.totalLp).Uint();
    }

    function _getMarketPreCompute(IPMarket market, MarketState memory state)
        private
        view
        returns (MarketPreCompute memory)
    {
        return state.getMarketPreCompute(_getPYIndexCurrent(market), block.timestamp);
    }

    function _getPYIndexCurrent(IPMarket market) private view returns (PYIndex) {
        (IStandardizedYield SY, , IPYieldToken YT) = market.readTokens();
        uint256 ytIndex = YT.pyIndexStored();
        uint256 pyIndexCurrent;
        if (YT.doCacheIndexSameBlock() && YT.pyIndexLastUpdatedBlock() == block.number) {
            pyIndexCurrent = ytIndex;
        } else {
            uint256 syIndex = SY.exchangeRate();
            pyIndexCurrent = Math.max(syIndex, ytIndex);
        }
        return PYIndex.wrap(pyIndexCurrent);
    }

    function _getPtRates(
        IPMarket market,
        MarketState memory state,
        uint32 duration
    )
        private
        view
        returns (
            int256 rateOracle,
            int256 rateLastTrade,
            int256 rateHypTrade
        )
    {
        rateOracle = Math.IONE.divDown(market.getPtToAssetRate(duration).Int());
        rateLastTrade = MarketMathCore._getExchangeRateFromImpliedRate(
            state.lastLnImpliedRate,
            state.expiry - block.timestamp
        );
        rateHypTrade = (rateLastTrade + rateOracle) / 2;
    }

    function _calcLpPrice(int256 totalHypotheticalAsset, int256 totalLp)
        private
        pure
        returns (int256)
    {
        return totalHypotheticalAsset.divDown(totalLp);
    }
}
