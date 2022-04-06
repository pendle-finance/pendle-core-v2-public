// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPMarketAddRemoveCallback {
    function addLiquidityCallback(
        uint256 lpToAccount,
        uint256 scyOwed,
        uint256 otOwed,
        bytes calldata data
    ) external;

    function removeLiquidityCallback(
        uint256 lpOwed,
        uint256 scyToAccount,
        uint256 otToAccount,
        bytes calldata data
    ) external;
}
