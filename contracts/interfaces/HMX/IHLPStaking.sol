// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IHLPStaking {
    function deposit(address to, uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getRewarders() external view returns (address[] memory);
}
