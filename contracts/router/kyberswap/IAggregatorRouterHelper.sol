// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IAggregationRouterHelper {
    function getScaledInputData(bytes calldata kybercall, uint256 newAmount)
        external
        pure
        returns (bytes memory);
}
