pragma solidity ^0.8.17;

import "./IPActionMarketAuxStatic.sol";
import "./IPActionMintRedeemStatic.sol";
import "./IPActionInfoStatic.sol";
import "./IPActionMarketCoreStatic.sol";
import "./IPActionVePendleStatic.sol";
import "./IPMiniDiamond.sol";
import "./IPActionStorageStatic.sol";

interface IPRouterStatic is
    IPActionMintRedeemStatic,
    IPActionInfoStatic,
    IPActionMarketAuxStatic,
    IPActionMarketCoreStatic,
    IPActionVePendleStatic,
    IPMiniDiamond,
    IPActionStorageStatic
{}
