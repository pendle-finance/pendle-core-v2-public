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

/// @dev Methods take `IPLoopPositionBox` (not `MarketCtx`) by design: the view reconstructs
/// `BoxData` from the factory and builds its own `MarketCtx` internally. The asymmetry vs
/// `IMoneyMarket` is intentional — callers (frontend/indexers) shouldn't have to pre-fetch
/// the full ctx just to query a view.
interface IMoneyMarketView {
    function moneyMarketName() external view returns (string memory);

    function moneyMarketBalances(IPLoopPositionBox box) external returns (uint256 mmPtBalance, uint256 mmDebtBalance);

    function thresholds(IPLoopPositionBox box) external view returns (uint256 ltv, uint256 liquidationThreshold);

    function liquidity(IPLoopPositionBox box) external view returns (uint256 borrowing, uint256 lending);

    function rewards(IPLoopPositionBox box) external returns (Reward[] memory borrowing, Reward[] memory lending);

    function limits(IPLoopPositionBox box) external view returns (Limits memory);

    function rates(IPLoopPositionBox box) external view returns (uint256 borrowing, uint256 lending);

    /// @notice Rate of 1 **wei** PT per 1 **wei** of debt token, scaled by 1e18
    ///         This means the result is unitless. The offchain side must scaled by the tokens' decimals.
    function ptDebtRate(IPLoopPositionBox box) external view returns (uint256 rateWad);
}
