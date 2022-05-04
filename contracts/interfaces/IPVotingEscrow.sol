// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.9;
pragma abicoder v2;

import "./IPVeToken.sol";

interface IPVotingEscrow {
    // ============= ACTIONS =============

    function lock(uint256 expiry, uint256 amount) external payable returns (uint256);

    function increaseLockAmount(address receiver, uint256 amount) external payable returns (uint256);

    function increaseLockDuration(uint256 duration) external payable returns (uint256);

    function withdraw(address user) external returns (uint256);
}
