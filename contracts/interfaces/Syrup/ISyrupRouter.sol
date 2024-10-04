// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface ISyrupRouter {
    function pool() external view returns (address);

    function deposit(uint256 amount_, bytes32 depositData_) external returns (uint256 shares_);
}
