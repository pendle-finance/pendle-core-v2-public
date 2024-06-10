// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDolomiteDToken {
    function mint(uint256 _amount) external returns (uint256);

    function redeem(uint256 _dAmount) external returns (uint256);
}
