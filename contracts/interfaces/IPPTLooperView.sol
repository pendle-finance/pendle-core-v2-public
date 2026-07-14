//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMoneyMarketView, Reward, Limits} from "./IMoneyMarketView.sol";

/// @notice Aggregate snapshot of a position. Returned by `getAll` — bundles every field
///         the seven prior individual getters used to return, so a frontend pays one factory
///         deploy/lookup per query instead of one per field.
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

/// @notice `getAll` is non-view because it will deploy the box and the money market clone
///         if they do not yet exist.
interface IPPTLooperView {
    event MoneyMarketViewRegistered(address spokeMM, address mmView);

    function moneyMarketView(address spokeMM) external view returns (IMoneyMarketView);

    function getAll(address owner, bytes32 boxId) external returns (PositionView memory);

    // ========== Admin functions ==========
    function registerMoneyMarketView(address spokeMM, address mmView) external;
}
