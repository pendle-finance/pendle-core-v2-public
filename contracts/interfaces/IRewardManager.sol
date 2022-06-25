// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface IRewardManager {
    function userRewardAccrued(address token, address user) external view returns (uint128);
}
