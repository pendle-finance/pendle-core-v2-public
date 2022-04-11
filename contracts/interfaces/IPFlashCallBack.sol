// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPFlashCallback {
    function pendleFlashCallback(
        address[] calldata tokens,
        uint256[] calldata amountsToPay,
        bytes calldata data
    ) external;
}
