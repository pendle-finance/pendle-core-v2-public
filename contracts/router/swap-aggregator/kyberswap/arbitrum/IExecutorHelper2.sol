// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IExecutorHelper2 {
    function executeKyberLimitOrder(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut
    ) external payable returns (uint256);
}
