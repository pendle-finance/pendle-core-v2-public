// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

////////// GENERATED FILE. DO NOT EDIT DIRECTLY.
// FOUNDRY_PROFILE=v2-script forge script script/GenEIP712.sol -- "./contracts/interfaces/IPPTLooper.sol" "IPPTLooperEIP712Types" '[]' "./contracts/pt-looping/PTLooperEIP712TypesEncodeDataLib.sol"

import {IPPTLooperEIP712Types} from "./../interfaces/IPPTLooper.sol";

/// @notice Generate EIP712 `encodeData` function for types in IPPTLooperEIP712Types based on specification:
/// https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata
// forgefmt: disable-next-item
library PTLooperEIP712TypesEncodeDataLib {
    // IPPTLooper.sol > IPPTLooperEIP712Types > BoxPermit
    function encodeData(IPPTLooperEIP712Types.BoxPermit memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "BoxPermit(address owner,bytes32 boxId,uint256 expiry,uint256 nonce)" 
        ); */
        bytes32 typeHash = 0x822aa76455d3f0b945088018ee29f25999f8e1b1cbe462cd90f78d0c038148ec;
        return keccak256(abi.encode(
            typeHash,
            data.owner,
            data.boxId,
            data.expiry,
            data.nonce
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > RequestHeader
    function encodeData(IPPTLooperEIP712Types.RequestHeader memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "RequestHeader(bytes32 boxId,uint256 expiry,uint32 sessionNonce,uint32 permitNonceCap,uint256 swapBridgeSlippage,bytes offchainMetadata)" 
        ); */
        bytes32 typeHash = 0x4b5c157e13c9c70173fbe4c990f516a87f1bcb79deeb7706156cfd0a4bb4ee84;
        return keccak256(abi.encode(
            typeHash,
            data.boxId,
            data.expiry,
            data.sessionNonce,
            data.permitNonceCap,
            data.swapBridgeSlippage,
            keccak256(data.offchainMetadata)
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > BoxApprovedCall
    function encodeData(IPPTLooperEIP712Types.BoxApprovedCall memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
        ); */
        bytes32 typeHash = 0xd3355b017a4df5ab14bfe30be8fc74cf288d6cbdd53b7fb9a45cb406e14cb425;
        return keccak256(abi.encode(
            typeHash,
            data.extRouter,
            data.approve,
            keccak256(data.callData)
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > BridgeData
    function encodeData(IPPTLooperEIP712Types.BridgeData memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "BridgeData(BoxApprovedCall call,uint256 maxAmount,uint256 nativeFee)" 
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
        ); */
        bytes32 typeHash = 0x2e509eca09b391e74bb50ce10f43a13d6dfd1390e626fcfc40c60b1d7369a4b0;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.call),
            data.maxAmount,
            data.nativeFee
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > IncreasePositionRequest
    function encodeData(IPPTLooperEIP712Types.IncreasePositionRequest memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "IncreasePositionRequest(RequestHeader header,address initTokenIn,uint256 initMinToPtSwapRate,uint256 minDebtToPtSwapRate,uint256 postBorrowMaxLTV,bool isZeroPriceImpact)" 
            "RequestHeader(bytes32 boxId,uint256 expiry,uint32 sessionNonce,uint32 permitNonceCap,uint256 swapBridgeSlippage,bytes offchainMetadata)" 
        ); */
        bytes32 typeHash = 0xb37d571e358db3b5130424792ae520a87def7c4a54a9d100801057de49dd0a56;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.header),
            data.initTokenIn,
            data.initMinToPtSwapRate,
            data.minDebtToPtSwapRate,
            data.postBorrowMaxLTV,
            data.isZeroPriceImpact
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > IncreasePositionMessage
    function encodeData(IPPTLooperEIP712Types.IncreasePositionMessage memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "IncreasePositionMessage(BoxPermit permit,BoxApprovedCall swap,uint256 fee,BridgeData bridge,uint256 amountDebtBorrowed,bytes postStateCheckData)" 
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
            "BoxPermit(address owner,bytes32 boxId,uint256 expiry,uint256 nonce)" 
            "BridgeData(BoxApprovedCall call,uint256 maxAmount,uint256 nativeFee)" 
        ); */
        bytes32 typeHash = 0x40d59af1d5bbd55280d0f7131b112cf40ffd6775f6ca26b477734c4dca0cf64e;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.permit),
            encodeData(data.swap),
            data.fee,
            encodeData(data.bridge),
            data.amountDebtBorrowed,
            keccak256(data.postStateCheckData)
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > DecreasePositionRequest
    function encodeData(IPPTLooperEIP712Types.DecreasePositionRequest memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "DecreasePositionRequest(RequestHeader header,uint256 minPtToDebtSwapRate,uint256 postWithdrawMaxLTV)" 
            "RequestHeader(bytes32 boxId,uint256 expiry,uint32 sessionNonce,uint32 permitNonceCap,uint256 swapBridgeSlippage,bytes offchainMetadata)" 
        ); */
        bytes32 typeHash = 0xf2fd81fd04f9cee0ece251f806445c3b1d5103fcd06f31002a34371094102b59;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.header),
            data.minPtToDebtSwapRate,
            data.postWithdrawMaxLTV
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > DecreasePositionMessage
    function encodeData(IPPTLooperEIP712Types.DecreasePositionMessage memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "DecreasePositionMessage(BoxPermit permit,BoxApprovedCall swap,BridgeData bridge,uint256 amountPtWithdrawn,uint256 fee,bytes postStateCheckData)" 
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
            "BoxPermit(address owner,bytes32 boxId,uint256 expiry,uint256 nonce)" 
            "BridgeData(BoxApprovedCall call,uint256 maxAmount,uint256 nativeFee)" 
        ); */
        bytes32 typeHash = 0x4acf1a63082999b1c5bc3be18a62b4549817bf7f6bf2999238c2eddb1cd71942;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.permit),
            encodeData(data.swap),
            encodeData(data.bridge),
            data.amountPtWithdrawn,
            data.fee,
            keccak256(data.postStateCheckData)
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > SwapBridgeWithdrawAllRequest
    function encodeData(IPPTLooperEIP712Types.SwapBridgeWithdrawAllRequest memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "SwapBridgeWithdrawAllRequest(RequestHeader header,bool receiveOnSpoke,address hubTokenOut,address dstTokenOut,uint256 minTokenWithdrawn)" 
            "RequestHeader(bytes32 boxId,uint256 expiry,uint32 sessionNonce,uint32 permitNonceCap,uint256 swapBridgeSlippage,bytes offchainMetadata)" 
        ); */
        bytes32 typeHash = 0x8ac3df3c6aafa50fff9c9cdb9de52954f7d1bcb8a41375bb202fca85c4f86cab;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.header),
            data.receiveOnSpoke,
            data.hubTokenOut,
            data.dstTokenOut,
            data.minTokenWithdrawn
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > SwapBridgeWithdrawAllMessage
    function encodeData(IPPTLooperEIP712Types.SwapBridgeWithdrawAllMessage memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "SwapBridgeWithdrawAllMessage(BoxPermit permit,BoxApprovedCall swap,BridgeData bridge,bytes postStateCheckData)" 
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
            "BoxPermit(address owner,bytes32 boxId,uint256 expiry,uint256 nonce)" 
            "BridgeData(BoxApprovedCall call,uint256 maxAmount,uint256 nativeFee)" 
        ); */
        bytes32 typeHash = 0x6cd5da344d135a773661e166411b132de126661c92b5d13b7b83c71ff0110f1f;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.permit),
            encodeData(data.swap),
            encodeData(data.bridge),
            keccak256(data.postStateCheckData)
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > ClaimMMRewardsRequest
    function encodeData(IPPTLooperEIP712Types.ClaimMMRewardsRequest memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "ClaimMMRewardsRequest(RequestHeader header,address extRewardController,bytes data,address[] rewardTokens)" 
            "RequestHeader(bytes32 boxId,uint256 expiry,uint32 sessionNonce,uint32 permitNonceCap,uint256 swapBridgeSlippage,bytes offchainMetadata)" 
        ); */
        bytes32 typeHash = 0xc43b1ddd31b47c3575e0cfab0ba34c9546a4f739fce4f13625dc9ae5cc44df62;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.header),
            data.extRewardController,
            keccak256(data.data),
            keccak256(abi.encodePacked(data.rewardTokens))
        ));
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > ClaimMMRewardsMessage
    function encodeData(IPPTLooperEIP712Types.ClaimMMRewardsMessage memory data) internal pure returns (bytes32) {
        /* bytes32 typeHash = keccak256(
            "ClaimMMRewardsMessage(BoxPermit permit)" 
            "BoxPermit(address owner,bytes32 boxId,uint256 expiry,uint256 nonce)" 
        ); */
        bytes32 typeHash = 0xeb325b74167005941f5d4aacf4aa3fd86a6d4dcb7695d06bcc66de38ad87d3c2;
        return keccak256(abi.encode(
            typeHash,
            encodeData(data.permit)
        ));
    }
}
