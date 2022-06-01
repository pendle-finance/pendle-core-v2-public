// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IRewardManager {
    function userRewardAccrued(address token, address user) external view returns (uint256);

    function rewardState(address token) external view returns (uint256 index, uint256 lastBalance);
}
