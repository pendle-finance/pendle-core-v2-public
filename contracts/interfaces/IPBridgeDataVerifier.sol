//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

struct BridgeInfo {
    uint256 originChainId;
    uint256 destinationChainId;
    /// @notice sender and receiver are the same
    address senderReceiver;
    address inputToken;
    uint256 inputAmount;
    address outputToken;
    uint256 minOutputAmount;
}

interface IPBridgeDataVerifier {
    function verify(
        address extRouter,
        bytes calldata callData,
        uint256 nativeFee,
        address approveTo,
        BridgeInfo calldata expectedInfo
    ) external view;
}
