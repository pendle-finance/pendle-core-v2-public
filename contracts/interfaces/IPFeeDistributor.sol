// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IPFeeDistributor {
    event Fund(uint256 indexed epoch, uint256 incentive);

    event ClaimReward(
        address indexed user,
        address indexed rewardToken,
        uint256 lastEpochClaimed,
        uint256 totalReward
    );

    function fund(uint256[] calldata rewardsForEpoch) external;

    function claimReward(address user) external returns (uint256 amountRewardOut);

    function incentivesForEpoch(uint256 epoch) external returns (uint256);
}
