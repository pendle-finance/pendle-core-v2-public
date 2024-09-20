// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IEquilibriaVault {
    function deposit(uint256 _amount) external returns (uint256);

    function withdraw(uint256 _shares) external returns (uint256);

    function getReward(address _account) external;

    function balance() external view returns (uint256);
}
