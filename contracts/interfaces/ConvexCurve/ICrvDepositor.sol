// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICrvDepositor {
    function crv() external view returns (address);

    function minter() external view returns (address);

    function deposit(uint256 _amount, bool _lock, address _stakeAddress) external;

    //deposit crv for cvxCrv
    //can locking immediately or defer locking to someone else by paying a fee.
    //while users can choose to lock or defer, this is mostly in place so that
    //the cvx reward contract isnt costly to claim rewards
    function depositAll(bool _lock, address _stakeAddress) external;
}
