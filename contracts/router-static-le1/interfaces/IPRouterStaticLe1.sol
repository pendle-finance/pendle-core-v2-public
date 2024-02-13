// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPActionMarketAuxStaticLe1.sol";
import "./IPActionMintRedeemStaticLe1.sol";
import "./IPActionInfoStaticLe1.sol";
import "./IPActionMarketCoreStaticLe1.sol";
import "./IPActionVePendleStaticLe1.sol";
import "./IPMiniDiamondLe1.sol";
import "./IPActionStorageStaticLe1.sol";

//solhint-disable-next-line no-empty-blocks
interface IPRouterStaticLe1 is
    IPActionMintRedeemStaticLe1,
    IPActionInfoStaticLe1,
    IPActionMarketAuxStaticLe1,
    IPActionMarketCoreStaticLe1,
    IPActionVePendleStaticLe1,
    IPMiniDiamondLe1,
    IPActionStorageStaticLe1
{

}
