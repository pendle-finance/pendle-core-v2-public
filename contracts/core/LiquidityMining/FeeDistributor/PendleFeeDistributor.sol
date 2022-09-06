// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../libraries/math/Math.sol";
import "../../../libraries/helpers/ArrayLib.sol";
import "../../../libraries/helpers/MiniHelpers.sol";
import "../../../libraries/math/WeekMath.sol";
import "../../../libraries/VeHistoryLib.sol";
import "../../../interfaces/IPFeeDistributor.sol";
import "../../../interfaces/IPFeeDistributorFactory.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PendleFeeDistributor is IPFeeDistributor {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using ArrayLib for address[];
    using VeBalanceLib for VeBalance;

    address public immutable factory;
    address public immutable pool;
    address public immutable rewardToken;
    uint256 public immutable startEpoch;

    // [user] => [epoch]
    mapping(address => uint256) public userLastClaimedEpoch;

    // [epoch] => [incentive]
    mapping(uint256 => uint256) public incentivesForEpoch;

    constructor(
        address _pool,
        address _rewardToken,
        uint256 _startEpoch
    ) {
        pool = _pool;
        factory = msg.sender;
        rewardToken = _rewardToken;
        startEpoch = _startEpoch;
    }

    function fund(uint256[] calldata epochs, uint256[] calldata rewardsForEpoch) external {
        require(epochs.length == rewardsForEpoch.length, "epochs length mismatched");

        uint256 totalRewardFunding = 0;
        uint256 lastFinishedEpoch = IPFeeDistributorFactory(factory).lastFinishedEpoch();
        for (uint256 i = 0; i < epochs.length; ++i) {
            uint256 epoch = epochs[i];
            uint256 incentive = rewardsForEpoch[i];

            require(epoch > lastFinishedEpoch, "invalid epoch");
            incentivesForEpoch[epoch] += incentive;
            totalRewardFunding += incentive;

            emit Fund(epoch, incentive);
        }

        IERC20(rewardToken).transferFrom(msg.sender, address(this), totalRewardFunding);
    }

    function claimReward(address user) external returns (uint256 amountRewardOut) {
        IPFeeDistributorFactory(factory).updateUserShare(user, pool);

        uint256 lastFinishedEpoch = IPFeeDistributorFactory(factory).lastFinishedEpoch();
        uint256 userEpoch = userLastClaimedEpoch[user];

        if (userEpoch == lastFinishedEpoch) return 0;
        if (userEpoch == 0) userEpoch = startEpoch;

        while (userEpoch < lastFinishedEpoch) {
            userEpoch += WeekMath.WEEK;

            uint256 incentive = incentivesForEpoch[userEpoch];
            if (incentive == 0) continue;

            (uint256 userShare, uint256 totalShare) = IPFeeDistributorFactory(factory)
                .getUserAndTotalSharesAt(user, pool, userEpoch);

            amountRewardOut += (userShare * incentive) / totalShare;
        }

        userLastClaimedEpoch[user] = lastFinishedEpoch;
        if (amountRewardOut > 0) {
            IERC20(rewardToken).safeTransfer(user, amountRewardOut);
        }

        emit ClaimReward(user, rewardToken, lastFinishedEpoch, amountRewardOut);
    }
}
