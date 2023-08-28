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
}
