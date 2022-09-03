// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IPFeeDistributor {
    event Fund(address indexed rewardToken, uint256 numEpoch, uint256 incentiveForEach);

    event ClaimReward(
        address indexed user,
        address indexed rewardToken,
        uint256 lastEpochClaimed,
        uint256 totalReward
    );

    function fund(
        address rewardToken,
        uint256 amount,
        uint256 numEpoch
    ) external;

    function updateUserShare(address user) external;

    function claimReward(address user, address rewardToken)
        external
        returns (uint256 amountRewardOut);

    function incentivesForEpoch(uint256 epoch, address rewardToken) external returns (uint256);
}
