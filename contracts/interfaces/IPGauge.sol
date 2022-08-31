// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IPGauge {
    function totalActiveSupply() external view returns (uint256);

    function activeBalance(address user) external view returns (uint256);
}
