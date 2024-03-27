// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "./IPActionAddRemoveLiqV3.sol";
import "./IPActionSwapPTV3.sol";
import "./IPActionSwapYTV3.sol";
import "./IPActionMiscV3.sol";
import "./IPActionCallbackV3.sol";
import "./IPActionStorageV4.sol";

interface IPAllActionV3 is
    IPActionAddRemoveLiqV3,
    IPActionSwapPTV3,
    IPActionSwapYTV3,
    IPActionMiscV3,
    IPActionCallbackV3,
    IPActionStorageV4
{}
