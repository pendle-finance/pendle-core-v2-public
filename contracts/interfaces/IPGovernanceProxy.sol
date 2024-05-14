// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPGovernanceProxy {
    struct Call {
        address target;
        uint256 value;
        bytes callData;
    }

    function pause(address[] calldata addrs) external;

    function aggregate(Call[] calldata calls) external payable returns (bytes[] memory rtnData);
}
