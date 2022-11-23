// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.17;

interface IAggregationRouterHelper {
    function getScaledInputData(bytes calldata kybercall, uint256 newAmount)
        external
        pure
        returns (bytes memory);
}
