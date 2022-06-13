// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../../interfaces/IPVeToken.sol";
import "../../../libraries/VeBalanceLib.sol";
import "../../../libraries/math/WeekMath.sol";

/**
 * @dev this contract is an abstract for its mainchain and sidechain variant
 * PRINCIPLE:
 *   - All functions implemented in this contract should be either view or pure
 *     to ensure that no writing logic is inheritted by sidechain version
 *   - Mainchain version will handle the logic which are:
 *        + Deposit, withdraw, increase lock, increase amount
 *        + Mainchain logic will be ensured to have _totalSupply = linear sum of
 *          all users' veBalance such that their locks are not yet expired
 *        + Mainchain contract reserves 100% the right to write on sidechain
 *        + No other transaction is allowed to write on sidechain storage
 */

abstract contract VotingEscrowToken is IPVeToken {
    // wrong name, should be VotingEscrowPendle
    using VeBalanceLib for VeBalance;
    using VeBalanceLib for LockedPosition;

    uint128 public constant WEEK = 1 weeks;
    uint128 public constant MAX_LOCK_TIME = 104 weeks;

    VeBalance internal _totalSupply;
    uint128 public lastSupplyUpdatedAt;

    mapping(address => LockedPosition) public positionData;

    constructor() {
        lastSupplyUpdatedAt = WeekMath.getCurrentWeekStart();
    }

    function balanceOf(address user) public view virtual returns (uint128) {
        if (isPositionExpired(user)) return 0;
        return positionData[user].convertToVeBalance().getCurrentValue();
    }

    function totalSupplyStored() public view virtual returns (uint128) {
        return _totalSupply.getCurrentValue();
    }

    function totalSupplyCurrent() external virtual returns (uint128);

    function isPositionExpired(address user) public view returns (bool) {
        return positionData[user].expiry < uint128(block.timestamp);
    }
}
