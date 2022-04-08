// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPRouterSCYAndForge {
    function mintSCYFromRawToken(
        uint256 netRawTokenIn,
        address SCY,
        uint256 minSCYOut,
        address recipient,
        address[] calldata path
    ) external returns (uint256 netSCYOut);

    function redeemSCYToRawToken(
        address SCY,
        uint256 netSCYIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] memory path
    ) external returns (uint256 netRawTokenOut);

    function mintYoFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minYoOut,
        address recipient,
        address[] calldata path
    ) external returns (uint256 netYoOut);

    function redeemYoToRawToken(
        address YT,
        uint256 netYoIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] memory path
    ) external returns (uint256 netRawTokenOut);
}
