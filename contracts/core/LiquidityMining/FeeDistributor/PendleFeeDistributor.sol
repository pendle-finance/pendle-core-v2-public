// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../libraries/math/Math.sol";
import "../../../libraries/helpers/ArrayLib.sol";
import "../../../libraries/helpers/MiniHelpers.sol";
import "../../../libraries/math/WeekMath.sol";
import "../../../libraries/Errors.sol";
import "../../../libraries/VeHistoryLib.sol";
import "../../../interfaces/IPFeeDistributor.sol";
import "../../../interfaces/IPFeeDistributorFactory.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PendleFeeDistributor is IPFeeDistributor, BoringOwnableUpgradeable {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using ArrayLib for address[];
    using VeBalanceLib for VeBalance;

    address public immutable factory;
    address public immutable pool;
    address public immutable rewardToken;
    uint256 public immutable startEpoch;

    uint256 public lastFinishedEpoch;

    // [user] => [epoch]
    mapping(address => uint256) public userLastClaimedEpoch;

    // [epoch] => [incentive]
    mapping(uint256 => uint256) public incentivesForEpoch;

    constructor(
        address _pool,
        address _rewardToken,
        uint256 _startEpoch
    ) initializer {
        pool = _pool;
        factory = msg.sender;
        rewardToken = _rewardToken;
        startEpoch = _startEpoch;
        lastFinishedEpoch = _startEpoch;
        __BoringOwnable_init();
    }

    function fund(uint256[] calldata rewardsForEpoch) external onlyOwner {
        uint256 epoch = lastFinishedEpoch;
        uint256 totalRewardFunding = 0;
        for (uint256 i = 0; i < rewardsForEpoch.length; ++i) {
            epoch += WeekMath.WEEK;
            uint256 incentive = rewardsForEpoch[i];

            incentivesForEpoch[epoch] += incentive;
            totalRewardFunding += incentive;

            emit Fund(epoch, incentive);
        }

        if (epoch > WeekMath.getCurrentWeekStart()) revert Errors.FDCantFundFutureEpoch();

        IERC20(rewardToken).transferFrom(msg.sender, address(this), totalRewardFunding);
        lastFinishedEpoch = epoch;
    }

    function claimReward(address user) external returns (uint256 amountRewardOut) {
        IPFeeDistributorFactory(factory).updateUserShare(user, pool);

        uint256 finishedEpoch = lastFinishedEpoch;
        uint256 userEpoch = userLastClaimedEpoch[user];

        if (userEpoch == finishedEpoch) return 0;
        if (userEpoch == 0) userEpoch = startEpoch;

        while (userEpoch < finishedEpoch) {
            userEpoch += WeekMath.WEEK;

            uint256 incentive = incentivesForEpoch[userEpoch];
            if (incentive == 0) continue;

            (uint256 userShare, uint256 totalShare) = IPFeeDistributorFactory(factory)
                .getUserAndTotalSharesAt(user, pool, userEpoch);

            if (userShare == 0) continue;

            amountRewardOut += (userShare * incentive) / totalShare;
        }

        userLastClaimedEpoch[user] = finishedEpoch;
        if (amountRewardOut > 0) {
            IERC20(rewardToken).safeTransfer(user, amountRewardOut);
        }

        emit ClaimReward(user, rewardToken, finishedEpoch, amountRewardOut);
    }
}
