// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPDepositBox} from "./IPDepositBox.sol";

interface IPDepositBoxFactory {
    function computeDepositBox(address owner, uint32 boxId)
        external
        view
        returns (address box, bytes32 salt, bool deployed);

    function deployDepositBox(address owner, uint32 boxId) external returns (IPDepositBox box);

    function BEACON_PROXY_CODE_CONTRACT() external view returns (address);

    function DEPOSIT_BOX_BEACON() external view returns (address);

    function DEPOSIT_BOX_CODE_HASH() external view returns (bytes32);
}
