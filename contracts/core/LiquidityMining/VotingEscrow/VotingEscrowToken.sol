// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

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

    uint128 public constant WEEK = 1 weeks;
    uint128 public constant MAX_LOCK_TIME = 104 weeks;

    struct LockedPosition {
        uint128 amount;
        uint128 expiry; // confirm can't use 2 slots
    }

    VeBalance internal _totalSupply;
    uint128 public lastSupplyUpdatedAt;

    mapping(address => LockedPosition) public positionData;

    constructor() {
        lastSupplyUpdatedAt = WeekMath.getCurrentWeekStart();
    }

    function balanceOf(address user) public view virtual returns (uint128) {
        // if this will be overriden, just don't write it here
        if (isPositionExpired(user)) return 0; // is this necessary? : yes, to be used in sidechain
        return convertToVeBalance(positionData[user]).getCurrentValue();
    }

    /**
     * @dev There will be a short delay every start of the week where this function
     * will be reverted, on both mainchain & sidechain. This also implies Gauge pause.
     * This will be resolved as soon as broadcastSupply is called on mainchain
     * @dev Gauges will use totalSupplyCurrent to get totalSupply, this will
     * prevent the pause for gauges on mainchain.
     */
    // hmm I don't like this pause
    function totalSupplyStored() public view virtual returns (uint128) {
        return _totalSupply.getCurrentValue();
    }

    // I really don't like the low-level logic here
    // Overall these kinds of logics should be abstracted out

    function totalSupplyCurrent() external virtual returns (uint128);

    function isPositionExpired(address user) public view returns (bool) {
        return positionData[user].expiry < uint128(block.timestamp);
    }

    function convertToVeBalance(LockedPosition memory position)
        public
        pure
        returns (VeBalance memory res)
    {
        res.slope = position.amount / MAX_LOCK_TIME;
        require(res.slope > 0, "zero slope");
        res.bias = res.slope * position.expiry;
    }

    function convertToVeBalance(uint128 amount, uint128 expiry)
        public
        pure
        returns (uint128, uint128)
    {
        VeBalance memory balance = convertToVeBalance(LockedPosition(amount, expiry));
        return (balance.bias, balance.slope);
    }
}
