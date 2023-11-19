// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IHMXVester {
    function esHMX() external view returns (address);

    function vestFor(address account, uint256 amount, uint256 duration) external;

    function claim(uint256 itemIndex) external;

    function hmx() external view returns (address);
}
