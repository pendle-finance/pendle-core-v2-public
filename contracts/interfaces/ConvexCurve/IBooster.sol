// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IBooster {
    function crv() external view returns (address);

    function poolLength() external view returns (uint256);

    function poolInfo(uint256) external view returns (address lpToken, address, address, address, address, bool);

    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns (bool);

    function depositAll(uint256 _pid, bool _stake) external returns (bool);

    function withdraw(uint256 _pid, uint256 _amount) external returns (bool);

    function withdrawAll(uint256 _pid) external returns (bool);
}
