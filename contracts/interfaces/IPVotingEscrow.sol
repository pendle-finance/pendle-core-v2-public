// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.13;

import "./IPVeToken.sol";

interface IPVotingEscrow {
    event Lock(address indexed user, uint128 amount, uint128 expiry);

    event IncreaseLockAmount(address indexed user, uint128 amount);

    event IncreaseLockDuration(address indexed user, uint128 duration);

    event Withdraw(address indexed user, uint128 amount);

    event BroadcastUserPosition(address indexed user, uint256[] chainIds);

    // ============= ACTIONS =============

    function lock(uint128 expiry, uint128 amount) external returns (uint128);

    function increaseLockAmount(uint128 amount) external returns (uint128);

    function increaseLockDuration(uint128 duration) external returns (uint128);

    function withdraw(address user) external returns (uint128);
}
