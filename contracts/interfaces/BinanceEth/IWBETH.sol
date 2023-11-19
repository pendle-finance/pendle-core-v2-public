// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IWBETH {
    function deposit(uint256 amount, address referral) external;

    function exchangeRate() external view returns (uint256 _exchangeRate);
}
