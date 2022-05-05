// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPGaugeController {
    function pendle() external returns (address);

    function updateAndGetGaugeReward(address gauge) external returns (uint256);

    function redeemLpStakerReward(address staker, uint256 amount) external;
}