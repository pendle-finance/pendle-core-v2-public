// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarketCallback.sol";
import "../../libraries/math/FixedPoint.sol";

abstract contract PendleRouterBase is IPMarketCallback {
    address public immutable marketFactory;

    modifier onlyPendleMarket(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "INVALID_MARKET");
        _;
    }

    constructor(address _marketFactory) {
        marketFactory = _marketFactory;
    }
}
