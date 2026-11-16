//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IPLoopPositionBox} from "./IPLoopPositionBox.sol";

struct Reward {
    address token;
    uint256 claimable;
}

struct Limits {
    uint256 minBorrowing;
    uint256 maxBorrowing;
    uint256 minBorrowingForRewards;
    uint256 minLending;
    uint256 maxLending;
    uint256 minLendingForRewards;
}

/// @dev Takes a box, not a `MarketCtx`, so off-chain callers need not build the ctx; the view reads
/// `BoxData` from the factory.
interface IMoneyMarketView {
    function moneyMarketName() external view returns (string memory);

    function moneyMarketBalances(IPLoopPositionBox box) external returns (uint256 mmPtBalance, uint256 mmDebtBalance);

    function thresholds(IPLoopPositionBox box) external view returns (uint256 ltv, uint256 liquidationThreshold);

    function liquidity(IPLoopPositionBox box) external view returns (uint256 borrowing, uint256 lending);

    function rewards(IPLoopPositionBox box) external returns (Reward[] memory borrowing, Reward[] memory lending);

    function limits(IPLoopPositionBox box) external view returns (Limits memory);

    function rates(IPLoopPositionBox box) external view returns (uint256 borrowing, uint256 lending);

    /// @notice Price of 1 PT wei in debt token wei, in WAD. Off-chain callers adjust for decimals.
    function ptDebtRate(IPLoopPositionBox box) external view returns (uint256 rateWad);
}
