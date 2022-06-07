// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.13;

import "./IPVeToken.sol";

interface IPVotingEscrow {
    // ============= ACTIONS =============

    function lock(uint128 expiry, uint128 amount) external returns (uint128);

    function increaseLockAmount(uint128 amount) external returns (uint128);

    function increaseLockDuration(uint128 duration) external returns (uint128);

    function withdraw(address user) external returns (uint128);
}
