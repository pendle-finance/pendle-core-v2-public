// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../interfaces/IPMarket.sol";
import "../core/libraries/math/PMath.sol";
import "../core/Market/MarketMathCore.sol";

contract PtAndLpToAsset {
    using PMath for int256;
    using PMath for uint256;
    using MarketMathCore for MarketState;

    function getLpToAssetRate(IPMarket market) public view returns (uint256 lpToAssetRate) {
        MarketState memory state = market.readState(address(0));
        uint256 pyIndexCurrent = _getPYIndexCurrent(market);
        MarketPreCompute memory comp = state.getMarketPreCompute(
            PYIndex.wrap(pyIndexCurrent),
            block.timestamp
        );

        int256 totalHypotheticalAsset = comp.totalAsset +
            state.totalPt.mulDown(int256(_getPtToAssetRate(market, state, pyIndexCurrent)));

        lpToAssetRate = uint256(totalHypotheticalAsset.divDown(state.totalLp));
    }

    function getPtToAssetRate(IPMarket market) public view returns (uint256 ptToAssetRate) {
        MarketState memory state = market.readState(address(0));
        return _getPtToAssetRate(market, state, _getPYIndexCurrent(market));
    }

    function _getPtToAssetRate(
        IPMarket market,
        MarketState memory state,
        uint256 pyIndexCurrent
    ) internal view returns (uint256 ptToAssetRate) {
        if (state.expiry <= block.timestamp) {
            (IStandardizedYield SY, , ) = market.readTokens();
            return (SY.exchangeRate().divDown(pyIndexCurrent));
        }
        uint256 timeToExpiry = state.expiry - block.timestamp;
        int256 assetToPtRate = MarketMathCore._getExchangeRateFromImpliedRate(
            state.lastLnImpliedRate,
            timeToExpiry
        );

        ptToAssetRate = uint256(PMath.IONE.divDown(assetToPtRate));
    }

    function _getPYIndexCurrent(IPMarket market) private view returns (uint256) {
        (IStandardizedYield SY, , IPYieldToken YT) = market.readTokens();

        uint256 syIndex = SY.exchangeRate();
        uint256 pyIndexStored = YT.pyIndexStored();

        if (YT.doCacheIndexSameBlock() && YT.pyIndexLastUpdatedBlock() == block.number) {
            return pyIndexStored;
        } else {
            return PMath.max(syIndex, pyIndexStored);
        }
    }
}
