// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IKyberMathHelper {
    function getSingleSidedSwapAmount(
        address kyberPool,
        uint256 startAmount,
        bool isToken0,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (uint256 amountToSwap);

    function previewDeposit(
        address kyberPool,
        int24 tickLower,
        int24 tickUpper,
        bool isToken0,
        uint256 amountIn
    ) external view returns (uint256);

    function previewRedeem(
        address kyberPool,
        int24 tickLower,
        int24 tickUpper,
        bool isToken0,
        uint256 amountShares
    ) external view returns (uint256);
}
