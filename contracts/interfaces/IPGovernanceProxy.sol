// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPGovernanceProxy {
    event GrantScopedAccess(address indexed caller, address indexed target, bytes4 indexed selector, bool state);
    struct Call {
        address target;
        uint256 value;
        bytes callData;
    }

    function pause(address[] calldata addrs) external;

    function aggregate(Call[] calldata calls) external payable returns (bytes[] memory rtnData);

    function aggregateWithScopedAccess(Call[] calldata calls) external payable returns (bytes[] memory rtnData);

    event SetAllowedSelectors(bytes4[] selectors, bytes32 indexed role);

    function grantScopedAccess(
        address caller,
        address[] memory targets,
        bytes4[] memory selectors,
        bool[] memory states
    ) external;
}
