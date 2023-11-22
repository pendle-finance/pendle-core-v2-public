// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../../interfaces/IPRouterStatic.sol";
import "./base/StorageLayout.sol";

// solhint-disable no-empty-blocks
contract PendleRouterStatic is Proxy, StorageLayout {
    constructor(address actionStorage) {
        owner = msg.sender;
        selectorToFacet[IPMiniDiamond.setFacetForSelectors.selector] = actionStorage;
    }

    function _implementation() internal view override returns (address res) {
        res = selectorToFacet[msg.sig];
        require(res != address(0), "selector not found");
    }
}
