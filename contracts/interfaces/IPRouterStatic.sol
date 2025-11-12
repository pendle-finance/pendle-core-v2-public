// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPActionInfoStatic.sol";
import "./IPActionMarketAuxStatic.sol";
import "./IPActionMarketCoreStatic.sol";
import "./IPActionMintRedeemStatic.sol";
import "./IPActionStorageStatic.sol";
import "./IPActionVePendleStatic.sol";
import "./IPMiniDiamond.sol";

//solhint-disable-next-line no-empty-blocks
interface IPRouterStatic is
    IPActionMintRedeemStatic,
    IPActionInfoStatic,
    IPActionMarketAuxStatic,
    IPActionMarketCoreStatic,
    IPActionVePendleStatic,
    IPMiniDiamond,
    IPActionStorageStatic
{}
