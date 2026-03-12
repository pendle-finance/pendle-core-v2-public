// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ApprovedCall {
    address token;
    uint256 amount;
    address approveTo;
    address callTo;
    bytes data;
}

interface IPDepositBox {
    function MANAGER() external view returns (address);

    function OWNER() external view returns (address);

    function BOX_ID() external view returns (uint32);

    function withdrawTo(address to, address token, uint256 amount) external;

    function approveAndCall(ApprovedCall memory call, address nativeRefund) external payable returns (bytes memory);
}
