// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPCommonSYFactory {
    function deploySY(bytes32 id, bytes memory constructorParams, address syOwner) external returns (address SY);

    function deployUpgradableSY(
        bytes32 id,
        bytes memory constructorParams,
        bytes memory initData,
        address syOwner
    ) external returns (address SY);
}
