// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/// @dev ProxyAdmin with configurable initial owner, since OZ's ProxyAdmin doesn't support setting owner in constructor.
contract PendleProxyAdmin is ProxyAdmin {
    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }
}