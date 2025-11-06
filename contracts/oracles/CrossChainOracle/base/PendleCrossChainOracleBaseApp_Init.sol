// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OAppUpgradeable, Origin, MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {OAppOptionsType3Upgradeable} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

abstract contract PendleCrossChainOracleBaseApp_Init is OAppUpgradeable, OAppOptionsType3Upgradeable {
    uint32 public immutable eid;

    uint256[100] private __gap;

    constructor(address _endpoint) OAppUpgradeable(_endpoint) {
        eid = ILayerZeroEndpointV2(_endpoint).eid();
    }

    function __PendleCrossChainOracleBaseApp_initialize(
        address _owner,
        address _delegate
    ) internal virtual onlyInitializing {
        __OApp_init(_delegate);
        _transferOwnership(_owner);
    }
}
