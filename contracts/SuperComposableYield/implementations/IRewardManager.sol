// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IRewardManager {
    function getGlobalReward(address rewardToken)
        external
        view
        returns (uint256 index, uint256 lastBalance);

    function getUserReward(address user, address rewardToken)
        external
        view
        returns (uint256 lastIndex, uint256 accruedReward);

    function getRewardTokens() external view returns (address[] memory);
}
