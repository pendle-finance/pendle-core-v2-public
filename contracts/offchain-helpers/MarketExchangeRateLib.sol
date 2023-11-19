// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../core/Market/MarketMathCore.sol";
import "../interfaces/IPMarket.sol";

library MarketExchangeRateLib {
    using PMath for int256;
    using MarketMathCore for MarketState;
    using MarketMathCore for MarketPreCompute;

    function getMarketExchangeRate(address market) internal view returns (uint256) {
        MarketState memory state = IPMarket(market).readState(address(0));
        MarketPreCompute memory comp = state.getMarketPreCompute(_getPYIndexCurrent(market), block.timestamp);

        return
            MarketMathCore._getExchangeRate(state.totalPt, comp.totalAsset, comp.rateScalar, comp.rateAnchor, 0).Uint();
    }

    function _getPYIndexCurrent(address market) private view returns (PYIndex) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();
        uint256 ytIndex = YT.pyIndexStored();
        uint256 pyIndexCurrent;
        if (YT.doCacheIndexSameBlock() && YT.pyIndexLastUpdatedBlock() == block.number) {
            pyIndexCurrent = ytIndex;
        } else {
            uint256 syIndex = SY.exchangeRate();
            pyIndexCurrent = PMath.max(syIndex, ytIndex);
        }
        return PYIndex.wrap(pyIndexCurrent);
    }
}
