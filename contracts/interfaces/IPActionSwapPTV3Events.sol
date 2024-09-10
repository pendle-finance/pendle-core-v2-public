// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPActionSwapPTV3Events {
    event SwapPtAndSy(
        address indexed caller,
        address indexed market,
        address indexed receiver,
        int256 netPtToAccount,
        int256 netSyToAccount
    );

    event SwapPtAndToken(
        address indexed caller,
        address indexed market,
        address indexed token,
        address receiver,
        int256 netPtToAccount,
        int256 netTokenToAccount,
        uint256 netSyInterm
    );
}
