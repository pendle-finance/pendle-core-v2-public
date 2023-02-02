// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

struct SwapData {
    SwapType swapType;
    address extRouter;
    bytes extCallData;
    bool needScale;
}

enum SwapType {
    NONE,
    KYBERSWAP,
    ONE_INCH,
    // WRAP / UNWRAP not used in Aggregator
    WRAP_ETH,
    UNWRAP_WETH
}

interface IPSwapAggregator {
    function swap(
        address tokenIn,
        uint256 amountIn,
        SwapData calldata swapData
    ) external payable;
}
