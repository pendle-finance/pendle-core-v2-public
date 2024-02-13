// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "./interfaces/IPRouterStaticLe1.sol";
import "./base/StorageLayoutLe1.sol";

// solhint-disable no-empty-blocks
contract PendleRouterStaticLe1 is Proxy, StorageLayoutLe1 {
    constructor(address actionStorage) {
        owner = msg.sender;
        selectorToFacet[IPMiniDiamondLe1.setFacetForSelectors.selector] = actionStorage;
    }

    function _implementation() internal view override returns (address res) {
        res = selectorToFacet[msg.sig];
        require(res != address(0), "selector not found");
    }
}
