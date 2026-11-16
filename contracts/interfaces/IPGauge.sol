// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPGauge {
    event RedeemRewards(address indexed user, uint256[] rewardsOut);
}
