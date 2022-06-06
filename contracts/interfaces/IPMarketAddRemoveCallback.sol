// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

interface IPMarketAddRemoveCallback {
    function addLiquidityCallback(
        address lpReceiver,
        uint256 lpToAccount,
        uint256 scyOwed,
        uint256 ptOwed,
        bytes calldata data
    ) external;

    function removeLiquidityCallback(
        address receiverScy,
        address receiverPt,
        uint256 lpOwed,
        uint256 scyToAccount,
        uint256 ptToAccount,
        bytes calldata data
    ) external;
}
