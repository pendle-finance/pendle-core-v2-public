// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

interface IPGauge {
    function redeemReward(address receiver) external returns (uint256[] memory);
}
