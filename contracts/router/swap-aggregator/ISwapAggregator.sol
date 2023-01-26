// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

struct SwapData {
    AGGREGATOR aggregatorType;
    address router;
    bytes callData;
}

enum AGGREGATOR {
    KYBERSWAP,
    ONE_INCH
}

interface ISwapAggregator {
    function swap(
        address tokenIn,
        uint256 amountIn,
        SwapData calldata swapData
    ) external payable;
}
