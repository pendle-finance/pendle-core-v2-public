// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../core/libraries/MiniHelpers.sol";
import "../../../interfaces/IPRouterStatic.sol";
import "../../../interfaces/IPVotingEscrowMainchain.sol";
import "../../../LiquidityMining/libraries/VeBalanceLib.sol";

contract ActionVePendleStatic is IPActionVePendleStatic {
    using VeBalanceLib for VeBalance;
    using VeBalanceLib for LockedPosition;

    uint128 private constant MAX_LOCK_TIME = 104 weeks;
    uint128 private constant MIN_LOCK_TIME = 1 weeks;

    IPVotingEscrowMainchain private immutable vePENDLE;

    constructor(IPVotingEscrowMainchain _vePENDLE) {
        vePENDLE = _vePENDLE;
    }

    function increaseLockPositionStatic(
        address user,
        uint128 additionalAmountToLock,
        uint128 newExpiry
    ) external view returns (uint128 newVeBalance) {
        if (!WeekMath.isValidWTime(newExpiry)) revert Errors.InvalidWTime(newExpiry);
        if (MiniHelpers.isTimeInThePast(newExpiry)) revert Errors.ExpiryInThePast(newExpiry);

        if (newExpiry > block.timestamp + MAX_LOCK_TIME) revert Errors.VEExceededMaxLockTime();
        if (newExpiry < block.timestamp + MIN_LOCK_TIME) revert Errors.VEInsufficientLockTime();

        LockedPosition memory oldPosition;

        {
            (uint128 amount, uint128 expiry) = vePENDLE.positionData(user);
            oldPosition = LockedPosition(amount, expiry);
        }

        if (newExpiry < oldPosition.expiry) revert Errors.VENotAllowedReduceExpiry();

        uint128 newTotalAmountLocked = additionalAmountToLock + oldPosition.amount;
        if (newTotalAmountLocked == 0) revert Errors.VEZeroAmountLocked();

        uint128 additionalDurationToLock = newExpiry - oldPosition.expiry;

        LockedPosition memory newPosition = LockedPosition(
            oldPosition.amount + additionalAmountToLock,
            oldPosition.expiry + additionalDurationToLock
        );

        VeBalance memory newBalance = newPosition.convertToVeBalance();
        return newBalance.getCurrentValue();
    }
}
