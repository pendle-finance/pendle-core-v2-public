// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPGauge {
    function totalActiveSupply() external view returns (uint256);

    function activeBalance(address user) external view returns (uint256);

    // only available for newer factories. please check the verified contracts
    event RedeemRewards(address indexed user, uint256[] rewardsOut);
}
