// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPMarketSwapCallback.sol";
import "./IPLimitRouter.sol";

interface IPActionCallbackV3 is IPMarketSwapCallback, IPLimitRouterCallback {}
