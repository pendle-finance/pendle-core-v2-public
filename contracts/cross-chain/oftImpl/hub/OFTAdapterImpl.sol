// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import {IPBridgePTFactory} from "../../../interfaces/IPBridgePTFactory.sol";
import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";

/// @notice Base OFT contract, without any additional functionality (like RateLimiter).
/// @notice Contract deployer must be IPBridgePTFactory for additional information.
///         This is for deterministic deployment.
/// @dev This contract inherits Ownable from OpenZeppelin v4.
contract OFTAdapterImpl is OFTAdapterUpgradeable {
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address ownerDelegate) external initializer {
        __OFTAdapter_init(ownerDelegate);
        _transferOwnership(ownerDelegate);
    }
}
