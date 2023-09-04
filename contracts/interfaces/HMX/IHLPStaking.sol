// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IHLPStaking {
    function deposit(address account, address token, uint256 amount) external;

    function withdraw(address stakingToken, uint256 amount) external;
}