// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILBTCMinterBase {
    function swapCBBTCToLBTC(uint256 amount) external;

    function relativeFee() external view returns (uint16);

    function remainingStake() external view returns (uint256);

    function stakeLimit() external view returns (uint256);
}
