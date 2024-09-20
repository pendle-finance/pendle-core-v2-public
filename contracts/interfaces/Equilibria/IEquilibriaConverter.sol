// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IEquilibriaConverter {
    function deposit(uint256 _amount) external returns (uint256);

    function estimateTotalConversion(uint256 _amount) external view returns (uint256);
}
