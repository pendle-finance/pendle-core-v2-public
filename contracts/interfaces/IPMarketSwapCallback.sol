// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPMarketSwapCallback {
    function swapCallback(int256 ptToAccount, int256 syToAccount, bytes calldata data) external;
}
