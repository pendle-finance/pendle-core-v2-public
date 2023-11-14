// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPLinearDistributor {
    event VestQueued(address indexed token, address indexed addr, uint256 amount);
    event Vested(address indexed token, address indexed addr, uint256 amount, uint256 duration);
    event Claim(address indexed token, address indexed addr, uint256 amount);

    struct DistributionData {
        uint128 accruedReward;
        uint128 unvestedReward;
        uint128 rewardPerSec;
        uint32 lastDistributedTime;
        uint32 endTime;
    }

    function queueVestAndClaim(
        address token,
        uint256 amountToVest
    ) external returns (uint256 amountOut);

    function claim(
        address token
    ) external returns (uint256 amountOut);
}