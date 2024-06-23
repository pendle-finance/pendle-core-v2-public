// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRenzoReztake {
    function rez() external view returns (address);

    function stake(uint256 _amount) external returns (uint256 totalStaked);

    function unStake(uint256 _amount) external;

    function claim(uint256 _index) external;
}
