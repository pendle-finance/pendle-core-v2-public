// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IPPTOFTAdapterFactory} from "../../../interfaces/IPPTOFTAdapterFactory.sol";
import {BoringOwnableUpgradeableV2} from "../../../core/libraries/BoringOwnableUpgradeableV2.sol";
import {OFTAdapterImpl} from "../../oftImpl/hub/OFTAdapterImpl.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PendlePTOFTAdapterFactory is IPPTOFTAdapterFactory, BoringOwnableUpgradeableV2, UUPSUpgradeable {
    error PTOFTAdapterExisted(address pt);

    address internal immutable _lzEndpoint;

    constructor(address lzEndpoint) {
        _disableInitializers();
        _lzEndpoint = lzEndpoint;
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
        __UUPSUpgradeable_init();
    }

    mapping(address pt => address) public ptAdapter;

    function createPtAdapter(address pt) external override onlyOwner returns (address) {
        if (ptAdapter[pt] != address(0)) revert PTOFTAdapterExisted(pt);

        OFTAdapterImpl adapter = new OFTAdapterImpl(pt, _lzEndpoint, owner);
        adapter.transferOwnership(owner);
        emit PtAdapterCreated(pt, address(adapter));

        return ptAdapter[pt] = address(adapter);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
