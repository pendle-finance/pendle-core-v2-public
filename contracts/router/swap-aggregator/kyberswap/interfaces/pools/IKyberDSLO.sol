// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKyberDSLO {
    struct Order {
        uint256 salt;
        address makerAsset;
        address takerAsset;
        address maker;
        address receiver;
        address allowedSender; // equals to Zero address on public orders
        uint256 makingAmount;
        uint256 takingAmount;
        uint256 feeConfig; // bit slot  1 -> 32 -> 160: isTakerAssetFee - amountTokenFeePercent - feeRecipient
        bytes makerAssetData;
        bytes takerAssetData;
        bytes getMakerAmount; // this.staticcall(abi.encodePacked(bytes, swapTakerAmount)) => (swapMakerAmount)
        bytes getTakerAmount; // this.staticcall(abi.encodePacked(bytes, swapMakerAmount)) => (swapTakerAmount)
        bytes predicate; // this.staticcall(bytes) => (bool)
        bytes interaction;
    }

    struct Signature {
        bytes orderSignature; // Signature to confirm quote ownership
        bytes opSignature; // OP Signature to confirm quote ownership
    }

    struct FillBatchOrdersParams {
        Order[] orders;
        Signature[] signatures;
        uint32[] opExpireTimes;
        uint256 takingAmount;
        uint256 thresholdAmount;
        address target;
    }
}
