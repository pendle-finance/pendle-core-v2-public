// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IAnkrLiquidStaking {
    function swap(uint256 shares, address receiverAddress) external;

    function stakeBonds() external payable;

    function stakeCerts() external payable;

    function getFreeBalance() external view returns (uint256);

    function getMinStake() external view returns (uint256);

    function getMinUnstake() external view returns (uint256);

    function flashPoolCapacity() external view returns (uint256);

    function getFlashUnstakeFee() external view returns (uint256);
}
