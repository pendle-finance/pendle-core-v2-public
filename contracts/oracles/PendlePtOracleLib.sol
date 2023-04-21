// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPMarket.sol";
import "../core/libraries/math/Math.sol";

library PendlePtOracleLib {
    using Math for uint256;

    /**
     * This function returns the twap rate PT/Asset on market
     * @param market market to get rate from
     * @param duration twap duration
     */
    function getPtToAssetRate(IPMarket market, uint32 duration)
        internal
        view
        returns (uint256 ptToAssetRate)
    {
        uint256 expiry = market.expiry();
        if (expiry <= block.timestamp) {
            return _getPtToAssetRatePostExpiry(market);
        }
        uint256 lnImpliedRate = _getMarketLnImpliedRate(market, duration);
        uint256 timeToExpiry = expiry - block.timestamp;
        uint256 assetToPtRate = uint256(
            MarketMathCore._getExchangeRateFromImpliedRate(lnImpliedRate, timeToExpiry)
        );

        ptToAssetRate = Math.ONE.divDown(assetToPtRate);
    }

    function _getMarketLnImpliedRate(IPMarket market, uint32 duration)
        private
        view
        returns (uint256)
    {
        uint32[] memory durations = new uint32[](2);
        durations[0] = duration;

        uint216[] memory lnImpliedRateCumulative = market.observe(durations);
        return (lnImpliedRateCumulative[1] - lnImpliedRateCumulative[0]) / duration;
    }

    function _getPtToAssetRatePostExpiry(IPMarket market) private view returns (uint256) {
        (IStandardizedYield SY, , IPYieldToken YT) = market.readTokens();

        uint256 syIndex = SY.exchangeRate();
        uint256 pyIndexCurrent;

        if (YT.doCacheIndexSameBlock() && YT.pyIndexLastUpdatedBlock() == block.number) {
            pyIndexCurrent = YT.pyIndexStored();
        } else {
            pyIndexCurrent = Math.max(syIndex, YT.pyIndexStored());
        }

        return syIndex.divDown(pyIndexCurrent);
    }
}
