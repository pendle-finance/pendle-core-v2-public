// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";
import "../../core/libraries/Errors.sol";
import "../../interfaces/IPFeeDistributor.sol";
import "../../interfaces/IPVotingEscrowMainchain.sol";
import "../../interfaces/IPVotingController.sol";
import "../libraries/WeekMath.sol";
import "../libraries/VeHistoryLib.sol";

contract PendleFeeDistributor is UUPSUpgradeable, BoringOwnableUpgradeable, IPFeeDistributor {
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;

    address public immutable votingController;
    address public immutable vePendle;
    address public immutable rewardToken;

    // [pool] => lastFinishedEpoch
    mapping(address => uint256) public lastFinishedEpoch;

    // [pool] => startTime
    mapping(address => uint256) public startEpoch;

    // [pool, user] => UserInfo
    mapping(address => mapping(address => UserInfo)) public userInfo;

    // [pool, epoch] => [incentive]
    mapping(address => mapping(uint256 => uint256)) public incentivesForEpoch;

    modifier ensureValidPool(address pool) {
        if (startEpoch[pool] == 0) revert Errors.FDInvalidPool(pool);
        _;
    }

    constructor(
        address _votingController,
        address _vePendle,
        address _rewardToken
    ) initializer {
        votingController = _votingController;
        vePendle = _vePendle;
        rewardToken = _rewardToken;
    }

    function addPool(address pool, uint256 _startEpoch) external onlyOwner {
        if (!WeekMath.isValidWTime(_startEpoch) || _startEpoch == 0)
            revert Errors.FDInvalidStartEpoch(_startEpoch);
        if (startEpoch[pool] != 0) revert Errors.FDPoolAlreadyExists(pool, startEpoch[pool]);

        startEpoch[pool] = _startEpoch;
        lastFinishedEpoch[pool] = _startEpoch - WeekMath.WEEK;
    }

    function setLastFinishedEpoch(address pool, uint256 _newLastFinishedEpoch)
        external
        onlyOwner
        ensureValidPool(pool)
    {
        if (lastFinishedEpoch[pool] >= _newLastFinishedEpoch)
            revert Errors.FDInvalidNewFinishedEpoch(
                lastFinishedEpoch[pool],
                _newLastFinishedEpoch
            );
        lastFinishedEpoch[pool] = _newLastFinishedEpoch;
    }

    function fund(
        address pool,
        uint256[] calldata epochs,
        uint256[] calldata rewardsForEpoch
    ) external ensureValidPool(pool) {
        if (epochs.length != rewardsForEpoch.length) revert Errors.FDEpochLengthMismatch();

        uint256 totalRewardFunding = 0;
        for (uint256 i = 0; i < rewardsForEpoch.length; ++i) {
            uint256 epoch = epochs[i];
            uint256 incentive = rewardsForEpoch[i];
            incentivesForEpoch[pool][epoch] += incentive;

            emit Fund(pool, epoch, incentive);

            totalRewardFunding += incentive;
        }
        IERC20(rewardToken).transferFrom(msg.sender, address(this), totalRewardFunding);
    }

    function claimReward(address user, address[] calldata pools)
        external
        returns (uint256 amountRewardOut)
    {
        for (uint256 i = 0; i < pools.length; ++i) {
            amountRewardOut = _accumulateUserReward(pools[i], user);
        }
        IERC20(rewardToken).safeTransfer(user, amountRewardOut);
    }

    function _accumulateUserReward(address pool, address user)
        internal
        ensureValidPool(pool)
        returns (uint256 totalReward)
    {
        uint256 finishedEpoch = lastFinishedEpoch[pool];
        uint256 userEpoch = userInfo[pool][user].epoch;
        uint256 iter = userInfo[pool][user].iter;

        if (userEpoch > finishedEpoch) return 0;
        if (userEpoch == 0) userEpoch = startEpoch[pool];

        uint256 length = _getUserCheckpointLength(pool, user);
        if (length == 0) {
            userInfo[pool][user].epoch = uint128(finishedEpoch);
            return 0;
        }

        Checkpoint memory checkpoint = _getUserCheckpointAt(pool, user, iter);
        Checkpoint memory nextCheckpoint;

        while (userEpoch <= finishedEpoch) {
            if (iter + 1 < length) {
                // We have at most 1 checkpoint per week, so while loop is not needed
                if (nextCheckpoint.timestamp <= checkpoint.timestamp) {
                    nextCheckpoint = _getUserCheckpointAt(pool, user, iter + 1);
                }
                if (nextCheckpoint.timestamp < userEpoch) {
                    iter++;
                    checkpoint = nextCheckpoint;
                }
            }

            if (checkpoint.timestamp < userEpoch) {
                uint256 userShare = checkpoint.value.getValueAt(uint128(userEpoch));
                uint256 totalShare = _getPoolTotalSharesAt(pool, uint128(userEpoch));
                if (userShare > 0) {
                    uint256 amountRewardOut = (userShare * incentivesForEpoch[pool][userEpoch]) /
                        totalShare;
                    totalReward += amountRewardOut;
                    emit ClaimReward(pool, user, userEpoch, amountRewardOut);
                }
            }
            userEpoch += WeekMath.WEEK;
        }

        userInfo[pool][user] = UserInfo({ epoch: uint128(userEpoch), iter: uint128(iter) });
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
        address pool,
        address user,
        uint256 index
    ) internal view returns (Checkpoint memory) {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).getUserHistoryAt(user, index);
        } else {
            return IPVotingController(votingController).getUserPoolHistoryAt(user, pool, index);
        }
    }

    function _getUserCheckpointLength(address pool, address user) internal view returns (uint256) {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).getUserHistoryLength(user);
        } else {
            return IPVotingController(votingController).getUserPoolHistoryLength(user, pool);
        }
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    // ----------------- upgrade-related -----------------

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
