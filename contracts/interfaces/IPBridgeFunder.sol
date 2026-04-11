// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

struct BridgeData {
    address bridgeToken;
    uint256 bridgeAmount;
    address feeToken;
    uint256 feeAmount;
    address bridgeExtRouter;
    bytes bridgeCalldata;
}

interface IPBridgeFunder {
    function bridge(BridgeData memory data) external returns (bytes memory);

    function withdraw(address receiver, address token, uint256 amount) external;
}
