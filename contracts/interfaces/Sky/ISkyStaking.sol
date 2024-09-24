// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ISkyStaking {
    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;
}
