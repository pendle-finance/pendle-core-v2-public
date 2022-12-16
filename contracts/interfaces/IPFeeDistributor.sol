// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPFeeDistributor {
    event Fund(uint256 indexed epoch, uint256 incentive);

    event ClaimReward(
        address indexed user,
        uint256 epoch,
        uint256 amountReward
    );

    function fund(uint256[] calldata epochs, uint256[] calldata rewardsForEpoch) external;

    function claimReward(address user) external returns (uint256 amountRewardOut);

    function incentivesForEpoch(uint256 epoch) external returns (uint256);
}
