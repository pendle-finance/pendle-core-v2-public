// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IConnext {
    // Used by the UI to calculate slippage
    function calculateSwap(
        bytes32 canonicalId,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256);
}
