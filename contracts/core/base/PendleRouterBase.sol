// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarketCallback.sol";
import "../../libraries/math/FixedPoint.sol";

abstract contract PendleRouterBase is IPMarketCallback {
    address public immutable marketFactory;

    modifier onlycallback(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "INVALID_MARKET");
        _;
    }

    constructor(address _marketFactory) {
        marketFactory = _marketFactory;
    }

    function callback(
        int256 amountOTIn,
        int256 amountLYTIn,
        bytes calldata data
    ) external virtual override returns (bytes memory res);
}
