// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPMarketAddRemoveCallback {
    function addLiquidityCallback(
        uint256 lpToAccount,
        uint256 lytNeed,
        uint256 otNeed,
        bytes calldata data
    ) external;

    function removeLiquidityCallback(
        uint256 lpToRemove,
        uint256 lytToAccount,
        uint256 otToAccount,
        bytes calldata data
    ) external;
}
