//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPStaticQuoter {
    function quote(
        uint256 chainidIn,
        address tokenIn,
        uint256 amountIn,
        uint256 chainIdOut,
        address tokenOut,
        uint256 slippage
    ) external view returns (uint256 minAmountOut);
}
