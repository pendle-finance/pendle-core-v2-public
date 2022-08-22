// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./IPActionAddRemoveLiq.sol";
import "./IPActionSwapPT.sol";
import "./IPActionSwapYT.sol";
import "./IPActionMintRedeem.sol";

interface IPAllAction is
    IPActionAddRemoveLiq,
    IPActionSwapPT,
    IPActionSwapYT,
    IPActionMintRedeem
{}
