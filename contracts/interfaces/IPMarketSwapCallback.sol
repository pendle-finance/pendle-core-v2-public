// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IPMarketSwapCallback {
    function swapCallback(
        int256 ptToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) external;
}
