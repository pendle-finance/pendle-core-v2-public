// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPOffchainStorage {
    function setStorageUint256(bytes32 key, uint256 value) external;

    function getUint256(bytes32 key) external view returns (uint256);
}