// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../../core/libraries/math/Math.sol";
import "../../core/libraries/Errors.sol";

import "../libraries/WeekMath.sol";
import "../libraries/VeHistoryLib.sol";

import "../../interfaces/IPFeeDistributor.sol";
import "../../interfaces/IPFeeDistributorFactory.sol";
import "../../interfaces/IPVotingEscrowMainchain.sol";
import "../../interfaces/IPVotingController.sol";

abstract contract DistributorBase is IPFeeDistributor, Initializable {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;

    struct UserInfo {
        uint128 epoch; // Last accounted epoch for each user
        uint128 iter;
    }

    address public votingController;
    address public vePendle;
    address public pool;
    address public rewardToken;
    uint256 public startEpoch;
    address public factory;

    // [user] => [info]
    mapping(address => UserInfo) public userInfo;

    // [epoch] => [incentive]
    mapping(uint256 => uint256) public incentivesForEpoch;

    function initialize(
        address _votingController,
        address _vePendle,
        address _pool,
        address _rewardToken,
        uint256 _startEpoch,
        address _factory
    ) external initializer {
        votingController = _votingController;
        vePendle = _vePendle;
        pool = _pool;
        rewardToken = _rewardToken;
        startEpoch = _startEpoch;
        factory = _factory;
    }

    function fund(uint256[] calldata epochs, uint256[] calldata rewardsForEpoch) external {
        if (epochs.length != rewardsForEpoch.length) {
            revert Errors.FDEpochLengthMismatch();
        }

        uint256 totalRewardFunding = 0;
        for (uint256 i = 0; i < rewardsForEpoch.length; ++i) {
            uint256 epoch = epochs[i];
            _ensureFundingValidEpoch(epoch);

            uint256 incentive = rewardsForEpoch[i];
            incentivesForEpoch[epoch] += incentive;
            emit Fund(epoch, incentive);

            totalRewardFunding += incentive;
        }
        IERC20(rewardToken).transferFrom(msg.sender, address(this), totalRewardFunding);
    }

    function claimReward(address user) external returns (uint256 amountRewardOut) {
        amountRewardOut = _accumulateUserReward(user);
        uint256 lastClaimedEpoch = _getLastFinishedEpoch();
        IERC20(rewardToken).safeTransfer(user, amountRewardOut);
    }

    function _accumulateUserReward(address user) internal returns (uint256 totalReward) {
        uint256 latestEpoch = _getLastFinishedEpoch();
        uint256 userEpoch = userInfo[user].epoch;

        if (userEpoch > latestEpoch) return 0;
        if (userEpoch == 0) userEpoch = startEpoch;

        uint256 length = _getUserCheckpointLength(user);
        if (length == 0) {
            userInfo[user].epoch = uint128(latestEpoch);
            return 0;
        }

        uint256 iter = userInfo[user].iter;
        Checkpoint memory checkpoint = _getUserCheckpointAt(user, iter);

        while (userEpoch <= latestEpoch) {
            if (iter + 1 < length) {
                // We have at most 1 checkpoint per week, so while loop is not needed
                Checkpoint memory nextCheckpoint = _getUserCheckpointAt(user, iter + 1);
                if (nextCheckpoint.timestamp < userEpoch) {
                    iter++;
                    checkpoint = nextCheckpoint;
                }
            }

            if (checkpoint.timestamp < userEpoch) {
                uint256 userShare = checkpoint.value.getValueAt(uint128(userEpoch));
                uint256 totalShare = _getPoolTotalSharesAt(uint128(userEpoch));
                if (userShare > 0) {
                    uint256 amountRewardOut = (userShare * incentivesForEpoch[userEpoch]) /
                        totalShare;
                    totalReward += amountRewardOut;
                    emit ClaimReward(user, userEpoch, amountRewardOut);
                }
            }
            userEpoch += WeekMath.WEEK;
        }

        userInfo[user] = UserInfo({ epoch: uint128(userEpoch), iter: uint128(iter) });
    }

    function _updatePool() internal {
        if (pool == vePendle) {
            IPVeToken(vePendle).totalSupplyCurrent();
        } else {
            IPVotingController(votingController).applyPoolSlopeChanges(pool);
        }
    }

    function _getPoolTotalSharesAt(uint128 timestamp) internal view returns (uint256) {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).totalSupplyAt(timestamp);
        } else {
            return IPVotingController(votingController).getPoolTotalVoteAt(pool, timestamp);
        }
    }

    function _getUserCheckpointAt(address user, uint256 index)
        internal
        view
        returns (Checkpoint memory)
    {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).getUserHistoryAt(user, index);
        } else {
            return IPVotingController(votingController).getUserPoolHistoryAt(user, pool, index);
        }
    }

    function _getUserCheckpointLength(address user) internal view returns (uint256) {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).getUserHistoryLength(user);
        } else {
            return IPVotingController(votingController).getUserPoolHistoryLength(user, pool);
        }
    }

    function _getLastFinishedEpoch() internal view virtual returns (uint256);

    function _ensureFundingValidEpoch(uint256 epoch) internal view virtual;

    uint256[100] private _gaps;
}
