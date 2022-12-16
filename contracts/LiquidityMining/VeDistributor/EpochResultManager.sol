// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IPVotingEscrowMainchain.sol";
import "../../interfaces/IPVotingController.sol";
import "../../interfaces/IPFeeDistributorFactory.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";
import "../libraries/VeHistoryLib.sol";
import "../libraries/WeekMath.sol";

/**
 * @dev
 *
 * Let's say user A lock vePendle at T, taking effects for totalSupply/totalVotes from T + EPOCH onward.
 *
 * The recorded timestamp for this lock will be floor(T / EPOCH) * EPOCH
 * Meaning, in order to account for epoch T's reward, we need to consider a checkpoint having timestamp <= T - EPOCH
 * a.k.a the latest checkpoint with timestamp < T
 */
abstract contract EpochResultManager is IPFeeDistributorFactory {
    using Math for uint256;
    using VeBalanceLib for VeBalance;
    using CheckpointHelper for Checkpoint;

    struct UserInfo {
        uint128 timestamp; // Last accounted epoch for each user
        uint128 iter;
    }

    address public immutable votingController;
    address public immutable vePendle;

    // [user, pool] => UserInfo
    mapping(address => mapping(address => UserInfo)) public userInfo;

    // [user, pool, epoch] => share
    mapping(address => mapping(address => mapping(uint256 => uint256))) internal userSharesAtEpoch;

    constructor(address _votingController, address _vePendle) {
        votingController = _votingController;
        vePendle = _vePendle;
    }

    function updateShares(address user, address pool) external {
        _updatePool(pool);
        _updateUserShares(user, pool);
    }

    function getUserAndTotalSharesAt(
        address user,
        address pool,
        uint256 epoch
    ) external view returns (uint256 userShare, uint256 totalShare) {
        uint128 userEpoch = userInfo[user][pool].timestamp;
        if (userEpoch < epoch) {
            revert Errors.FDUserSharesNotUpdatedToEpoch(userEpoch, epoch);
        }

        userShare = userSharesAtEpoch[user][pool][epoch];
        totalShare = _getPoolTotalSharesAt(pool, epoch.Uint128());
    }

    function _updateUserShares(address user, address pool) internal {
        uint128 latestEpoch = WeekMath.getCurrentWeekStart();
        uint128 userEpoch = userInfo[user][pool].timestamp;

        if (userEpoch > latestEpoch) return;
        if (userEpoch == 0) userEpoch = _getPoolStartTime(pool);

        uint256 length = _getUserCheckpointLength(user, pool);
        if (length == 0) {
            userInfo[user][pool].timestamp = latestEpoch;
            return;
        }

        uint256 iter = userInfo[user][pool].iter;
        Checkpoint memory checkpoint = _getUserCheckpointAt(user, pool, iter);

        while (userEpoch <= latestEpoch) {
            if (iter + 1 < length) {
                // We have at most 1 checkpoint per week, so while loop is not needed
                Checkpoint memory nextCheckpoint = _getUserCheckpointAt(user, pool, iter + 1);
                if (nextCheckpoint.timestamp < userEpoch) {
                    iter++;
                    checkpoint = nextCheckpoint;
                }
            }

            if (checkpoint.timestamp < userEpoch) {
                userSharesAtEpoch[user][pool][userEpoch] = checkpoint.value.getValueAt(
                    userEpoch
                );
            }
            userEpoch += WeekMath.WEEK;
        }

        userInfo[user][pool] = UserInfo({ timestamp: userEpoch, iter: uint128(iter) });
    }

    function _updatePool(address pool) internal {
        if (pool == vePendle) {
            IPVeToken(vePendle).totalSupplyCurrent();
        } else {
            IPVotingController(votingController).applyPoolSlopeChanges(pool);
        }
    }

    function _getPoolTotalSharesAt(address pool, uint128 timestamp)
        internal
        view
        returns (uint256)
    {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).totalSupplyAt(timestamp);
        } else {
            return IPVotingController(votingController).getPoolTotalVoteAt(pool, timestamp);
        }
    }

    function _getUserCheckpointAt(
        address user,
        address pool,
        uint256 index
    ) internal view returns (Checkpoint memory) {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).getUserHistoryAt(user, index);
        } else {
            return IPVotingController(votingController).getUserPoolHistoryAt(user, pool, index);
        }
    }

    function _getUserCheckpointLength(address user, address pool) internal view returns (uint256) {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).getUserHistoryLength(user);
        } else {
            return IPVotingController(votingController).getUserPoolHistoryLength(user, pool);
        }
    }

    function _getPoolStartTime(address pool) internal view virtual returns (uint64);

    uint256[100] private _gaps;
}
