// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPGovernanceProxy {
    event ModifyScopedAccess(address indexed caller, bytes4 indexed selector, address indexed target, bool access);

    event ModifySelectorAdmin(address indexed addr, bytes4 indexed selector, bool isAdmin);

    event SetAllowedSelectors(bytes4[] selectors, bytes32 indexed role); // Deprecated

    struct Call {
        address target;
        uint256 value;
        bytes callData;
    }

    function pause(address[] calldata addrs) external;

    function aggregate(Call[] calldata calls) external payable returns (bytes[] memory rtnData);

    function aggregateWithScopedAccess(Call[] calldata calls) external payable returns (bytes[] memory rtnData);

    function isSelectorAdminOf(address addr, bytes4 selector) external view returns (bool);

    function hasScopedAccess(address caller, bytes4 selector, address target) external view returns (bool);

    function modifySelectorAdmin(address addr, bytes4[] memory selectors, bool[] memory isAdmins) external;

    function modifyScopedAccess(
        address caller,
        address[] memory targets,
        bytes4 selector,
        bool[] memory accesses
    ) external;
}
