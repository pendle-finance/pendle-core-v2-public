// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

/* GENERATED FILE. DO NOT EDIT DIRECTLY.
FOUNDRY_PROFILE=v2-script forge script script/GenEIP712.sol -- './contracts/interfaces/IPPTLooper.sol' 'IPPTLooperEIP712Types' '[]' './contracts/pt-looping/PTLooperEIP712TypesEncodeDataLib.sol'
*/

import {IPPTLooperEIP712Types} from "./../interfaces/IPPTLooper.sol";

/// @notice Generate EIP712 `encodeData` function for types in IPPTLooperEIP712Types based on specification:
/// https://eips.ethereum.org/EIPS/eip-712#definition-of-encodedata
/// @dev tempReplaceMem for typeHash is ALWAYS written after the other replacements, because of out-of-region memory write.
// forgefmt: disable-next-item
library PTLooperEIP712TypesEncodeDataLib {
    // IPPTLooper.sol > IPPTLooperEIP712Types > Execution
    function encodeData(IPPTLooperEIP712Types.Execution memory data) internal pure
        tempReplaceMem(_mPos(data), 0, encodeData(data.calls))
        /* TypeHash calculation: keccak256(
            "Execution(bytes[] calls,uint256 deadline)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0x2731bab67703f25265d364e0e113c4017ffa557ce8afa5889af81fb8de0dff83)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 96) }
    }
    
    function _mPos(IPPTLooperEIP712Types.Execution memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > RequestHeader
    function encodeData(IPPTLooperEIP712Types.RequestHeader memory data) internal pure
        /* TypeHash calculation: keccak256(
            "RequestHeader(bytes32 boxId,uint256 expiry,uint256 swapBridgeSlippage,bytes32 offchainMetadataHash)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0x821bd07beb0c9815c324abec6fdf02735804d21c9aa9d963dea50c2a5d099e59)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 160) }
    }
    
    function _mPos(IPPTLooperEIP712Types.RequestHeader memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > BoxApprovedCall
    function encodeData(IPPTLooperEIP712Types.BoxApprovedCall memory data) internal pure
        tempReplaceMem(_mPos(data), 64, encodeData(data.callData))
        /* TypeHash calculation: keccak256(
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0xd3355b017a4df5ab14bfe30be8fc74cf288d6cbdd53b7fb9a45cb406e14cb425)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 128) }
    }
    
    function _mPos(IPPTLooperEIP712Types.BoxApprovedCall memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > BridgeData
    function encodeData(IPPTLooperEIP712Types.BridgeData memory data) internal pure
        tempReplaceMem(_mPos(data), 0, encodeData(data.call))
        /* TypeHash calculation: keccak256(
            "BridgeData(BoxApprovedCall call,uint256 maxAmount,uint256 nativeFee)" 
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0x2e509eca09b391e74bb50ce10f43a13d6dfd1390e626fcfc40c60b1d7369a4b0)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 128) }
    }
    
    function _mPos(IPPTLooperEIP712Types.BridgeData memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > IncreasePositionRequest
    function encodeData(IPPTLooperEIP712Types.IncreasePositionRequest memory data) internal pure
        tempReplaceMem(_mPos(data), 0, encodeData(data.header))
        /* TypeHash calculation: keccak256(
            "IncreasePositionRequest(RequestHeader header,address initTokenIn,uint256 initMinToPtSwapRate,uint256 minDebtToPtSwapRate,uint256 postBorrowMaxLTV,bool isZeroPriceImpact)" 
            "RequestHeader(bytes32 boxId,uint256 expiry,uint256 swapBridgeSlippage,bytes32 offchainMetadataHash)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0x8fe1153584d333f5ea73b33aa49631061934154d52d99b5a71eb6fb7b1083e4a)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 224) }
    }
    
    function _mPos(IPPTLooperEIP712Types.IncreasePositionRequest memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > IncreasePositionMessage
    function encodeData(IPPTLooperEIP712Types.IncreasePositionMessage memory data) internal pure
        tempReplaceMem(_mPos(data), 64, encodeData(data.swap))
        tempReplaceMem(_mPos(data), 160, encodeData(data.bridge))
        tempReplaceMem(_mPos(data), 256, encodeData(data.postStateCheckData))
        /* TypeHash calculation: keccak256(
            "IncreasePositionMessage(address owner,bool swapInitToken,BoxApprovedCall swap,uint256 minSwapRate,uint256 fee,BridgeData bridge,uint256 amountDebtBorrowed,uint256 flashAmount,bytes postStateCheckData)" 
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
            "BridgeData(BoxApprovedCall call,uint256 maxAmount,uint256 nativeFee)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0x9f254442c96b08d2176fd44748fb9ed910a3d39aaf389b88d8a10506e22b9965)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 320) }
    }
    
    function _mPos(IPPTLooperEIP712Types.IncreasePositionMessage memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > DecreasePositionRequest
    function encodeData(IPPTLooperEIP712Types.DecreasePositionRequest memory data) internal pure
        tempReplaceMem(_mPos(data), 0, encodeData(data.header))
        /* TypeHash calculation: keccak256(
            "DecreasePositionRequest(RequestHeader header,uint256 minPtToDebtSwapRate,uint256 postWithdrawMaxLTV,bool redeemWithPY)" 
            "RequestHeader(bytes32 boxId,uint256 expiry,uint256 swapBridgeSlippage,bytes32 offchainMetadataHash)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0x61b256fba1c5d9e3e04d71b4bc3604b30d83b34c5f626ef62479b8caac40282c)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 160) }
    }
    
    function _mPos(IPPTLooperEIP712Types.DecreasePositionRequest memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > DecreasePositionMessage
    function encodeData(IPPTLooperEIP712Types.DecreasePositionMessage memory data) internal pure
        tempReplaceMem(_mPos(data), 32, encodeData(data.swap))
        tempReplaceMem(_mPos(data), 96, encodeData(data.bridge))
        tempReplaceMem(_mPos(data), 224, encodeData(data.postStateCheckData))
        /* TypeHash calculation: keccak256(
            "DecreasePositionMessage(address owner,BoxApprovedCall swap,uint256 minSwapRate,BridgeData bridge,uint256 amountPtWithdrawn,uint256 fee,uint256 flashAmount,bytes postStateCheckData)" 
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
            "BridgeData(BoxApprovedCall call,uint256 maxAmount,uint256 nativeFee)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0xe1084c1d7fa444be31f398b89301944c5ba04a1f5296534519de59ab6738eea5)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 288) }
    }
    
    function _mPos(IPPTLooperEIP712Types.DecreasePositionMessage memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > SwapBridgeWithdrawAllRequest
    function encodeData(IPPTLooperEIP712Types.SwapBridgeWithdrawAllRequest memory data) internal pure
        tempReplaceMem(_mPos(data), 0, encodeData(data.header))
        /* TypeHash calculation: keccak256(
            "SwapBridgeWithdrawAllRequest(RequestHeader header,bool receiveOnSpoke,address hubTokenOut,address dstTokenOut,uint256 minTokenWithdrawn)" 
            "RequestHeader(bytes32 boxId,uint256 expiry,uint256 swapBridgeSlippage,bytes32 offchainMetadataHash)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0x97fe4994ae4134ffa7d8bebba2ff21ca5ab9b59939502108614e0634e320cabf)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 192) }
    }
    
    function _mPos(IPPTLooperEIP712Types.SwapBridgeWithdrawAllRequest memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    // IPPTLooper.sol > IPPTLooperEIP712Types > SwapBridgeWithdrawAllMessage
    function encodeData(IPPTLooperEIP712Types.SwapBridgeWithdrawAllMessage memory data) internal pure
        tempReplaceMem(_mPos(data), 32, encodeData(data.swap))
        tempReplaceMem(_mPos(data), 96, encodeData(data.bridge))
        tempReplaceMem(_mPos(data), 128, encodeData(data.postStateCheckData))
        /* TypeHash calculation: keccak256(
            "SwapBridgeWithdrawAllMessage(address owner,BoxApprovedCall swap,uint256 minSwapRate,BridgeData bridge,bytes postStateCheckData)" 
            "BoxApprovedCall(address extRouter,address approve,bytes callData)" 
            "BridgeData(BoxApprovedCall call,uint256 maxAmount,uint256 nativeFee)" 
        ); */
        tempReplaceMem(_mPos(data), -32, 0x7cc1b15ccedaf263db15ec8f89f9160e8f4ba28e2c396709482a83c6fa6f16af)
        returns (bytes32 res)
    {
        assembly { res := keccak256(sub(data, 32), 192) }
    }
    
    function _mPos(IPPTLooperEIP712Types.SwapBridgeWithdrawAllMessage memory data) private pure returns (bytes32 res) {
        assembly { res := data }
    }
    
    function encodeData(bytes memory data) internal pure returns (bytes32 res) {
        assembly { res := keccak256(add(data, 32), mload(data)) }
    }
    
    function encodeData(bytes[] memory data) internal pure returns (bytes32 res) {
        uint256 n = data.length;
        bytes32[] memory encodedData = new bytes32[](n);
        for (uint256 i = 0; i < n; ++i) encodedData[i] = encodeData(data[i]);
        assembly { res := keccak256(add(encodedData, 32), shl(5, n)) }
    }
    
    // ========== Helper functions ==========
    
    modifier tempReplaceMem(bytes32 mPos, int256 ofs, bytes32 val) {
        bytes32 temp;
        assembly { temp := mload(add(mPos, ofs)) mstore(add(mPos, ofs), val) }
        _;
        assembly { mstore(add(mPos, ofs), temp) }
    }
}
