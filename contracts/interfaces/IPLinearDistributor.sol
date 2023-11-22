// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IPLinearDistributor {
    event VestQueued(address indexed token, address indexed addr, uint256 amount);
    event Vested(address indexed token, address indexed addr, uint256 amount, uint256 duration);
    event Claim(address indexed token, address indexed addr, uint256 amount);

    struct DistributionData {
        uint128 accruedReward;
        uint128 unvestedReward;
        // [irregular uint192] reward tokens might be up to 1e18 decimals, at 1e18 based, the reward per sec might be very close to 1e38 limit of uint128
        uint192 rewardPerSec;
        uint32 lastDistributedTime;
        uint32 endTime;
    }

    function queueVestAndClaim(address token, uint256 amountToVest) external returns (uint256 amountOut);

    function claim(address token) external returns (uint256 amountOut);
}
