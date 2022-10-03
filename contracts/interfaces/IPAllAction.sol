// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.17;

import "./IPActionAddRemoveLiq.sol";
import "./IPActionSwapPT.sol";
import "./IPActionSwapYT.sol";
import "./IPActionSwapPTYT.sol";
import "./IPActionMintRedeem.sol";
import "./IPActionMisc.sol";

interface IPAllAction is
    IPActionAddRemoveLiq,
    IPActionSwapPT,
    IPActionSwapYT,
    IPActionSwapPTYT,
    IPActionMintRedeem,
    IPActionMisc
{}
