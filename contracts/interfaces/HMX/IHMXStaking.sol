// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IHMXStaking {
    function getAllRewarders() external view returns (address[] memory);

    function userTokenAmount(address, address) external view returns (uint256);

    function withdraw(address stakingToken, uint256 amount) external;
}
