// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRewardManager {
    function userReward(address token, address user) external view returns (uint128 index, uint128 accrued);
}
