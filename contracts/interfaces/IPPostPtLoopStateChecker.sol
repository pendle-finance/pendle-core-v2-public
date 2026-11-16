// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {MarketCtx} from "./IMoneyMarket.sol";

interface IPPostPtLoopStateChecker {
    function check(MarketCtx memory ctx, bytes calldata data) external;
}
