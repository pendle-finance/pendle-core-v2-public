// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRewards {
    function operator() external view returns (address);

    function stake(address, uint256) external;

    function stakeFor(address, uint256) external;

    function withdraw(uint256, bool) external returns (bool);

    function withdrawAndUnwrap(uint256, bool) external returns (bool);

    function exit(address) external;

    function getReward(address /*_account*/, bool /*_claimExtras*/) external;

    function getReward() external;

    function queueNewRewards(uint256) external;

    function notifyRewardAmount(uint256) external;

    function addExtraReward(address) external;

    function rewardToken() external returns (address);

    function rewardPerToken() external returns (uint256);

    function rewardPerTokenStored() external view returns (uint256);

    function extraRewardsLength() external view returns (uint256);

    function extraRewards(uint256) external returns (address);

    function stakingToken() external returns (address);

    function lastTimeRewardApplicable() external view returns (uint256);
}
