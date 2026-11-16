//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMoneyMarketView, Reward, Limits} from "./IMoneyMarketView.sol";

/// @notice A snapshot of a position, returned by `getAll`.
struct PositionView {
    uint256 mmPtBalance;
    uint256 mmDebtBalance;
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 borrowingLiquidity;
    uint256 lendingLiquidity;
    Reward[] borrowingRewards;
    Reward[] lendingRewards;
    Limits limits;
    uint256 borrowingRate;
    uint256 lendingRate;
    uint256 ptDebtRateWad;
}

/// @notice `getAll` is not `view`: it deploys the box and the money market if they are missing.
interface IPPTLooperView {
    event MoneyMarketViewRegistered(address spokeMMBeacon, address mmView);

    function moneyMarketView(address spokeMMBeacon) external view returns (IMoneyMarketView);

    function getAll(address owner, bytes32 boxId) external returns (PositionView memory);

    // ========== Admin functions ==========
    function registerMoneyMarketView(address spokeMMBeacon, address mmView) external;
}
