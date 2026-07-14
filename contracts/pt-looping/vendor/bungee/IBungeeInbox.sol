// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @notice Partial interface obtained from https://etherscan.io/address/0x5e0f8e7337c8955d2124b8e85ca74af884b3e124#code
/// @notice Only use part of the SORInbox interface
interface IBungeeSORInbox {
    struct BasicRequest {
        uint256 originChainId;
        uint256 destinationChainId;
        uint256 deadline;
        uint256 nonce;
        address sender;
        address receiver;
        address delegate;
        address bungeeGateway;
        uint32 switchboardId;
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 minOutputAmount;
        uint256 refuelAmount;
    }

    struct SingleOutputRequest {
        BasicRequest basicReq;
        address swapOutputToken;
        uint256 minSwapOutput;
        bytes32 metadata;
        bytes affiliateFees;
        uint256 minDestGas;
        bytes destinationPayload;
        address exclusiveTransmitter;
    }

    function createRequest(SingleOutputRequest memory singleOutputRequest, address refundAddress) external payable;
}
