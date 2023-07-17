// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPExternalRewardDistributor {
    struct RewardData {
        uint160 rewardPerSec;
        uint32 lastDistributedTime;
        uint32 startTime;
        uint32 endTime;
    }

    event DistributeReward(address indexed market, address indexed rewardToken, uint256 amount);

    event SetRewardData(address indexed market, address indexed token, RewardData data);

    function getRewardTokens(address market) external view returns (address[] memory);

    function redeemRewards() external;
}
