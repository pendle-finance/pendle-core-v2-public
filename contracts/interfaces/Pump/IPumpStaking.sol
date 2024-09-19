// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPumpStaking {
    function stake(uint256 amount) external;

    function unstakeInstant(uint256 amount) external;

    function onlyAllowStake() external view returns (bool);

    function instantUnstakeFee() external view returns (uint256);

    function pendingStakeAmount() external view returns (uint256);
}
