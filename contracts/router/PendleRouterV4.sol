// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../interfaces/IPActionStorageV4.sol";
import "./RouterStorage.sol";

contract PendleRouterV4 is Proxy, RouterStorage {
    constructor(address _owner, address actionStorage) {
        RouterStorage.CoreStorage storage $ = _getCoreStorage();
        $.owner = _owner;
        $.selectorToFacet[IPActionStorageV4.setSelectorToFacets.selector] = actionStorage;
    }

    function _implementation() internal view override returns (address) {
        RouterStorage.CoreStorage storage $ = _getCoreStorage();
        address facet = $.selectorToFacet[msg.sig];
        require(facet != address(0), "INVALID_SELECTOR");
        return facet;
    }

    receive() external payable override {}
}
