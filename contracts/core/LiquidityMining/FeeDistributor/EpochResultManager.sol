// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleFeeDistributor.sol";
import "../../../interfaces/IPVotingEscrow.sol";
import "../../../interfaces/IPVotingController.sol";
import "../../../interfaces/IPFeeDistributorFactory.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";
import "../../../libraries/VeHistoryLib.sol";
import "../../../libraries/math/WeekMath.sol";

abstract contract EpochResultManager is IPFeeDistributorFactory {
    using Math for uint256;
    using ArrayLib for address[];
    using VeBalanceLib for VeBalance;
    using CheckpointHelper for Checkpoint;

    struct UserInfo {
        uint128 timestamp;
        uint128 iter;
    }

    address public immutable votingController;
    address public immutable vePendle;

    // [user, pool] => UserInfo
    mapping(address => mapping(address => UserInfo)) public userInfo;

    // [user, pool, epoch] => share
    mapping(address => mapping(address => mapping(uint256 => uint256))) internal userShareAtEpoch;

    constructor(address _votingController, address _vePendle) {
        votingController = _votingController;
        vePendle = _vePendle;
    }

    function updateUserShare(address user, address pool) external {
        _updateExternalGlobalShares(pool);
        _updateUserShare(user, pool);
    }

    function getUserAndTotalSharesAt(
        address user,
        address pool,
        uint256 epoch
    ) external view returns (uint256 userShare, uint256 totalShare) {
        userShare = userShareAtEpoch[user][pool][epoch];
        totalShare = _getExternalTotalShares(pool, epoch.Uint128());
    }

    function _updateUserShare(address user, address pool) internal {
        uint128 currentEpoch = WeekMath.getCurrentWeekStart();
        uint128 userEpoch = userInfo[user][pool].timestamp;

        if (userEpoch == currentEpoch) return;
        if (userEpoch == 0) userEpoch = _getPoolStartTime(pool);

        uint256 length = _getExternalUserHistoryLength(user, pool);
        if (length == 0) {
            userInfo[user][pool].timestamp = currentEpoch;
            return;
        }

        uint128 iter = userInfo[user][pool].iter;
        Checkpoint memory lowerCheckpoint = _getExternalUserCheckpointAt(user, pool, iter);
        Checkpoint memory upperCheckpoint;

        if (iter + 1 < length) {
            upperCheckpoint = _getExternalUserCheckpointAt(user, pool, iter + 1);
        }

        while (userEpoch < currentEpoch) {
            userEpoch += WeekMath.WEEK;

            iter = _moveIterToNextEpoch(
                user,
                pool,
                length,
                iter,
                lowerCheckpoint,
                upperCheckpoint,
                userEpoch
            );

            if (userEpoch >= lowerCheckpoint.timestamp) {
                userShareAtEpoch[user][pool][userEpoch] = lowerCheckpoint.value.getValueAt(
                    userEpoch
                );
            }
        }

        userInfo[user][pool] = UserInfo({ timestamp: currentEpoch, iter: iter });
    }

    function _moveIterToNextEpoch(
        address user,
        address pool,
        uint256 userHistoryLength,
        uint128 iter,
        Checkpoint memory lowerCheckpoint,
        Checkpoint memory upperCheckpoint,
        uint128 nextEpoch
    ) internal view returns (uint128) {
        while (iter + 1 < userHistoryLength && nextEpoch > upperCheckpoint.timestamp) {
            lowerCheckpoint.assignWith(upperCheckpoint);
            if (iter + 2 < userHistoryLength) {
                upperCheckpoint.assignWith(_getExternalUserCheckpointAt(user, pool, iter + 2));
            }
            ++iter;
        }
        return iter;
    }

    function _updateExternalGlobalShares(address pool) internal {
        if (pool == vePendle) {
            IPVeToken(vePendle).totalSupplyCurrent();
        } else {
            IPVotingController(votingController).applyPoolSlopeChanges(pool);
        }
    }

    function _getExternalTotalShares(address pool, uint128 timestamp)
        internal
        view
        returns (uint256)
    {
        if (pool == vePendle) {
            return IPVotingEscrow(vePendle).totalSupplyAt(timestamp);
        } else {
            return IPVotingController(votingController).getPoolTotalVoteAt(pool, timestamp);
        }
    }

    function _getExternalUserCheckpointAt(
        address user,
        address pool,
        uint256 index
    ) internal view returns (Checkpoint memory) {
        if (pool == vePendle) {
            return IPVotingEscrow(vePendle).getUserHistoryAt(user, index);
        } else {
            return IPVotingController(votingController).getUserPoolHistoryAt(user, pool, index);
        }
    }

    function _getExternalUserHistoryLength(address user, address pool)
        internal
        view
        returns (uint256)
    {
        if (pool == vePendle) {
            return IPVotingEscrow(vePendle).getUserHistoryLength(user);
        } else {
            return IPVotingController(votingController).getUserPoolHistoryLength(user, pool);
        }
    }

    function _getPoolStartTime(address pool) internal view virtual returns (uint64);
}
