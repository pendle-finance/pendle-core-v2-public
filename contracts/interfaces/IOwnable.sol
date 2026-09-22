// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IOwnable {
    function owner() external returns (address);
    function transferOwnership(address newOwner, bool direct, bool renounce) external;
}
