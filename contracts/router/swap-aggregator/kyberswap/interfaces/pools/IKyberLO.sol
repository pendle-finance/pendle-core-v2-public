// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKyberLO {
    struct Order {
        uint256 salt;
        address makerAsset;
        address takerAsset;
        address maker;
        address receiver;
        address allowedSender; // equals to Zero address on public orders
        uint256 makingAmount;
        uint256 takingAmount;
        address feeRecipient;
        uint32 makerTokenFeePercent;
        bytes makerAssetData;
        bytes takerAssetData;
        bytes getMakerAmount; // this.staticcall(abi.encodePacked(bytes, swapTakerAmount)) => (swapMakerAmount)
        bytes getTakerAmount; // this.staticcall(abi.encodePacked(bytes, swapMakerAmount)) => (swapTakerAmount)
        bytes predicate; // this.staticcall(bytes) => (bool)
        bytes permit; // On first fill: permit.1.call(abi.encodePacked(permit.selector, permit.2))
        bytes interaction;
    }

    struct FillBatchOrdersParams {
        Order[] orders;
        bytes[] signatures;
        uint256 takingAmount;
        uint256 thresholdAmount;
        address target;
    }
}
