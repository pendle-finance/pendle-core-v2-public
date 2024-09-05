// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IAggregationExecutor {
    struct Swap {
        bytes data;
        bytes32 selectorAndFlags; // [selector (32 bits) + empty (192 bits) + flags (32 bits)]; selector is 4 most significant bytes; flags are stored in 4 least significant bytes.
    }

    struct SwapExecutorDescription {
        Swap[][] swapSequences;
        address tokenIn;
        address tokenOut;
        address to;
        uint256 deadline;
        bytes positiveSlippageData;
    }

    function callBytes(bytes calldata data) external payable; // 0xd9c45357

    // callbytes per swap sequence
    function swapSingleSequence(bytes calldata data) external;

    function finalTransactionProcessing(
        address tokenIn,
        address tokenOut,
        address to,
        bytes calldata destTokenFeeData
    ) external;
}
