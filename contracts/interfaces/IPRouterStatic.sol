// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPActionMarketAuxStatic.sol";
import "./IPActionMintRedeemStatic.sol";
import "./IPActionInfoStatic.sol";
import "./IPActionMarketCoreStatic.sol";
import "./IPActionVePendleStatic.sol";
import "./IPMiniDiamond.sol";
import "./IPActionStorageStatic.sol";

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
