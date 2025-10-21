// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OAppUpgradeable, Origin, MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {OAppOptionsType3Upgradeable} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";

abstract contract PendleCrossChainOracleBaseApp_Init is OAppUpgradeable, OAppOptionsType3Upgradeable {
    address payable public immutable refundAddress;

    uint256[100] private __gap;

    constructor(address _endpoint, address payable _refundAddress) OAppUpgradeable(_endpoint) {
        refundAddress = _refundAddress;
    }

    function initialize(address _owner, address _delegate) external virtual initializer {
        __OApp_init(_delegate);
        _transferOwnership(_owner);
    }
}
