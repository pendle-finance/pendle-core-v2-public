//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IPLoopPositionBox, BoxData} from "./IPLoopPositionBox.sol";

/// @notice What every money market call acts on. Built from `BoxData` with `createMarketCtx`.
struct MarketCtx {
    IPLoopPositionBox box;
    bytes32 mmPayload;
    address collateral;
    address debtAsset;
}

function createMarketCtx(IPLoopPositionBox box, BoxData memory bd) pure returns (MarketCtx memory) {
    return MarketCtx({box: box, mmPayload: bd.mmPayload, collateral: bd.spokePt, debtAsset: bd.spokeDebtToken});
}

interface IMoneyMarket {
    function initialize(MarketCtx memory ctx) external;

    function lend(MarketCtx memory ctx, uint256 amount) external returns (uint256 actualAmount);

    function withdraw(MarketCtx memory ctx, uint256 amount) external returns (uint256 actualAmount);

    function borrow(MarketCtx memory ctx, uint256 amount) external returns (uint256 actualAmount);

    function repay(MarketCtx memory ctx, uint256 amount) external returns (uint256 actualAmount);

    function collateralBalance(MarketCtx memory ctx) external returns (uint256 balance);

    function debtBalance(MarketCtx memory ctx) external returns (uint256 balance);

    /// @notice Oracle price of 1 PT wei in debt token wei, in WAD.
    function oraclePtDebtRate(MarketCtx memory ctx) external view returns (uint256 rate);
}
