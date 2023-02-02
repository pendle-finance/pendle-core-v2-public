// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

struct SwapData {
    AggregatorType aggregatorType;
    address extRouter;
    bytes extCallData;
}

enum AggregatorType {
    KYBERSWAP,
    ONE_INCH
}

interface IPSwapAggregator {
    function swap(
        address tokenIn,
        uint256 amountIn,
        bool needScale,
        SwapData calldata swapData
    ) external payable;
}
