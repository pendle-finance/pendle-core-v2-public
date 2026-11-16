// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IPDepositBox} from "../../interfaces/IPDepositBox.sol";
import {IPDepositBoxFactory} from "../../interfaces/IPDepositBoxFactory.sol";
import {DepositBox} from "./DepositBox.sol";

contract DepositBoxFactory is IPDepositBoxFactory {
    /// @dev creation code of OpenZeppelin's BeaconProxy
    address public immutable BEACON_PROXY_CODE_CONTRACT;
    address public immutable DEPOSIT_BOX_BEACON;
    bytes32 public immutable DEPOSIT_BOX_CODE_HASH;

    constructor(address beaconProxyCodeContract_, address depositBoxBeacon_) {
        BEACON_PROXY_CODE_CONTRACT = beaconProxyCodeContract_;
        DEPOSIT_BOX_BEACON = depositBoxBeacon_;
        DEPOSIT_BOX_CODE_HASH =
            keccak256(abi.encodePacked(beaconProxyCodeContract_.code, abi.encode(depositBoxBeacon_, "")));
    }

    function computeDepositBox(address owner, uint32 boxId)
        public
        view
        returns (address box, bytes32 salt, bool deployed)
    {
        salt = keccak256(abi.encode(owner, boxId));
        box = Create2.computeAddress(salt, DEPOSIT_BOX_CODE_HASH);
        deployed = box.code.length > 0;
    }

    function deployDepositBox(address owner, uint32 boxId) external returns (IPDepositBox) {
        (address box, bytes32 salt, bool deployed) = computeDepositBox(owner, boxId);
        if (deployed) {
            return IPDepositBox(box);
        }

        bytes memory bytecode = abi.encodePacked(BEACON_PROXY_CODE_CONTRACT.code, abi.encode(DEPOSIT_BOX_BEACON, ""));
        assert(Create2.deploy(0, salt, bytecode) == box);
        DepositBox(payable(box)).initialize(owner, boxId);
        return IPDepositBox(box);
    }
}
