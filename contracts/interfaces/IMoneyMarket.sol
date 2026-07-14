//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IPLoopPositionBox, BoxData} from "./IPLoopPositionBox.sol";

interface IMoneyMarketEvents {
    event Borrowed(IPLoopPositionBox indexed box, address indexed asset, uint256 amount, uint256 balanceBefore);
    event Lent(IPLoopPositionBox indexed box, address indexed asset, uint256 amount, uint256 balanceBefore);
    event Repaid(IPLoopPositionBox indexed box, address indexed asset, uint256 amount, uint256 balanceBefore);
    event Withdrawn(IPLoopPositionBox indexed box, address indexed asset, uint256 amount, uint256 balanceBefore);
    event RewardsClaimed(address indexed rewardController, address[] rewardTokens, uint256[] claimedAmount);
}

/// @notice The (box, payload, collateral, debt) tuple every MM op resolves against. Built once
/// per call site from `BoxData` and threaded through the MM interface so each function takes one
/// ctx arg instead of 3–4 separate ones.
struct MarketCtx {
    IPLoopPositionBox box;
    bytes32 mmPayload;
    address collateral;
    address debtAsset;
}

function createMarketCtx(IPLoopPositionBox box, BoxData memory bd) pure returns (MarketCtx memory) {
    return MarketCtx({box: box, mmPayload: bd.mmPayload, collateral: bd.spokePt, debtAsset: bd.spokeDebtToken});
}

interface IMoneyMarket is IMoneyMarketEvents {
    function initialize(MarketCtx memory ctx) external;

    function lend(MarketCtx memory ctx, uint256 amount)
        external
        returns (uint256 actualAmount, uint256 postCollateralBalance);

    function withdraw(MarketCtx memory ctx, uint256 amount)
        external
        returns (uint256 actualAmount, uint256 postCollateralBalance);

    function borrow(MarketCtx memory ctx, uint256 amount)
        external
        returns (uint256 actualAmount, uint256 postDebtBalance);

    function repay(MarketCtx memory ctx, uint256 amount)
        external
        returns (uint256 actualAmount, uint256 postDebtBalance);

    function collateralBalance(MarketCtx memory ctx) external returns (uint256 balance);

    function debtBalance(MarketCtx memory ctx) external returns (uint256 balance);

    // @notice Oracle price for 1 raw PT wei expressed in raw debt wei, WAD-scaled
    function oraclePtDebtRate(MarketCtx memory ctx) external view returns (uint256 rate);

    function claimRewards(
        MarketCtx memory ctx,
        address extRewardController,
        bytes calldata data,
        address[] memory rewardTokens
    ) external returns (uint256[] memory claimedAmount);
}
