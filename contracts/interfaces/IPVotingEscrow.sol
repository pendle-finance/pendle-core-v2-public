// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.13;

import "./IPVeToken.sol";

interface IPVotingEscrow {
    event NewLockPosition(address indexed user, uint128 amount, uint128 expiry);

    event Withdraw(address indexed user, uint128 amount);

    event BroadcastUserPosition(address indexed user, uint256[] chainIds);

    // ============= ACTIONS =============

    function increaseLockPosition(uint128 additionalAmountToLock, uint128 expiry)
        external
        returns (uint128);

    function withdraw(address user) external returns (uint128);
}
