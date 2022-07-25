// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./IPVeToken.sol";
import "../libraries/VeBalanceLib.sol";

interface IPVotingEscrow {
    event NewLockPosition(address indexed user, uint128 amount, uint128 expiry);

    event Withdraw(address indexed user, uint128 amount);

    event BroadcastTotalSupply(VeBalance newTotalSupply, uint256[] chainIds);

    event BroadcastUserPosition(address indexed user, uint256[] chainIds);

    // ============= ACTIONS =============

    function increaseLockPosition(uint128 additionalAmountToLock, uint128 expiry)
        external
        returns (uint128);

    function withdraw() external returns (uint128);
}
