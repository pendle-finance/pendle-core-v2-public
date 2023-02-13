// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.17;

import "./IPActionAddRemoveLiq.sol";
import "./IPActionSwapPT.sol";
import "./IPActionSwapYT.sol";
import "./IPActionMintRedeem.sol";
import "./IPActionMisc.sol";
import "./IPMarketSwapCallback.sol";
import "./IDiamondLoupe.sol";

interface IPAllAction is
    IPActionAddRemoveLiq,
    IPActionSwapPT,
    IPActionSwapYT,
    IPActionMintRedeem,
    IPActionMisc,
    IPMarketSwapCallback,
    IDiamondLoupe
{}
