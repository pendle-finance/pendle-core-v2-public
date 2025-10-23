// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPGauge {
    event RedeemRewards(address indexed user, uint256[] rewardsOut);

    event UpdateActiveBalance(address indexed user, uint256 newActiveBalance);

    function totalActiveSupply() external view returns (uint256);

    function activeBalance(address user) external view returns (uint256);
}
