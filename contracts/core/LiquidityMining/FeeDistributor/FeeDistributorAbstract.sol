// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../libraries/math/Math.sol";
import "../../../libraries/helpers/ArrayLib.sol";
import "../../../libraries/helpers/MiniHelpers.sol";
import "../../../libraries/math/WeekMath.sol";
import "../../../libraries/VeHistoryLib.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract FeeDistributorAbstract {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using ArrayLib for address[];
    using VeBalanceLib for VeBalance;

    struct UserInfo {
        uint128 timestamp;
        uint128 iter;
    }

    uint256 public immutable deployedEpoch;

    // [user] => [UserInfo]
    mapping(address => UserInfo) internal userInfo;

    // [user, rewardToken] => userLastClaimedEpoch
    mapping(address => mapping(address => uint256)) internal userLastClaimedEpoch;

    // [user, epoch] => share
    mapping(address => mapping(uint256 => uint256)) internal userShareAtEpoch;

    // [epoch, rewardToken] => amount (uint256)
    mapping(uint256 => mapping(address => uint256)) public incentivesForEpoch;

    constructor() {
        deployedEpoch = WeekMath.getCurrentWeekStart();
    }

    function fund(
        address rewardToken,
        uint256 amount,
        uint256 numEpoch
    ) external {
        uint256 epoch = WeekMath.getCurrentWeekStart();
        uint256 incentiveForEach = amount / numEpoch;
        for (uint256 i = 0; i < numEpoch; ++i) {
            epoch += WeekMath.WEEK;
            incentivesForEpoch[epoch][rewardToken] += incentiveForEach;
        }
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    function updateUserShare(address user) external {
        _updateUserShare(user);
    }

    function claimReward(address user, address rewardToken)
        external
        returns (uint256 amountRewardOut)
    {
        _updateGlobalShares();
        _updateUserShare(user);

        uint128 currentEpoch = WeekMath.getCurrentWeekStart();
        uint256 rewardEpoch = userLastClaimedEpoch[user][rewardToken];

        if (rewardEpoch == currentEpoch) return 0;
        if (rewardEpoch == 0) rewardEpoch = deployedEpoch;

        while (rewardEpoch < currentEpoch) {
            rewardEpoch += WeekMath.WEEK;
            uint256 userShare = userShareAtEpoch[user][rewardEpoch];
            if (userShare == 0) continue;

            uint256 incentive = incentivesForEpoch[rewardEpoch][rewardToken];
            if (incentive == 0) continue;

            amountRewardOut += (userShare * incentive) / _getTotalSharesAt(rewardEpoch);
        }

        userLastClaimedEpoch[user][rewardToken] = currentEpoch;
        if (amountRewardOut > 0) {
            IERC20(rewardToken).safeTransfer(user, amountRewardOut);
        }
    }

    function _updateUserShare(address user) internal {
        uint128 currentEpoch = WeekMath.getCurrentWeekStart();
        uint128 userEpoch = userInfo[user].timestamp;

        if (userEpoch == currentEpoch) return;
        if (userEpoch == 0) userEpoch = uint128(deployedEpoch);

        uint256 length = _getUserCheckpointsLength(user);
        if (length == 0) {
            userInfo[user].timestamp = currentEpoch;
            return;
        }

        uint128 iter = userInfo[user].iter;
        Checkpoint memory lowerCheckpoint = _getUserCheckpointAt(user, iter);
        Checkpoint memory upperCheckpoint;

        if (iter + 1 < length) {
            upperCheckpoint = _getUserCheckpointAt(user, iter + 1);
        }

        while (userEpoch < currentEpoch) {
            userEpoch += WeekMath.WEEK;

            iter = _moveIterToNextEpoch(
                user,
                length,
                iter,
                lowerCheckpoint,
                upperCheckpoint,
                userEpoch
            );

            if (userEpoch >= lowerCheckpoint.timestamp) {
                uint256 shares = lowerCheckpoint.value.getValueAt(userEpoch);
                if (shares > 0) {
                    userShareAtEpoch[user][userEpoch] = shares;
                }
            }
        }

        userInfo[user] = UserInfo({ timestamp: currentEpoch, iter: iter });
    }

    function _moveIterToNextEpoch(
        address user,
        uint256 userHistoryLength,
        uint128 iter,
        Checkpoint memory lowerCheckpoint,
        Checkpoint memory upperCheckpoint,
        uint128 nextEpoch
    ) internal view returns (uint128) {
        while (iter + 1 < userHistoryLength && nextEpoch >= upperCheckpoint.timestamp) {
            lowerCheckpoint = upperCheckpoint;
            if (iter + 2 < userHistoryLength) {
                upperCheckpoint = _getUserCheckpointAt(user, iter + 2);
            }
            ++iter;
        }
        return iter;
    }

    function _updateGlobalShares() internal virtual;

    function _getUserCheckpointsLength(address user) internal view virtual returns (uint256);

    function _getUserCheckpointAt(address user, uint256 index)
        internal
        view
        virtual
        returns (Checkpoint memory);

    function _getTotalSharesAt(uint256 timestamp) internal view virtual returns (uint256);
}
