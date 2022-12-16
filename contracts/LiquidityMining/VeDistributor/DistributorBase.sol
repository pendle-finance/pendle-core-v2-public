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

abstract contract DistributorBase is IPFeeDistributor, Initializable {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;

    address public pool;
    address public rewardToken;
    uint256 public startEpoch;
    address public factory;

    // [user] => [epoch]
    mapping(address => uint256) public userUnclaimedEpoch;

    // [epoch] => [incentive]
    mapping(uint256 => uint256) public incentivesForEpoch;

    function initialize(
        address _pool,
        address _rewardToken,
        uint256 _startEpoch,
        address _factory
    ) external initializer {
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
        IPFeeDistributorFactory(factory).updateShares(user, pool);

        uint256 finishedEpoch = _getLastFinishedEpoch();
        uint256 userEpoch = userUnclaimedEpoch[user];

        if (userEpoch > finishedEpoch) return 0;

        // Since totalShare should strictly be 0 by startEpoch. We can skip this epoch.
        if (userEpoch == 0) userEpoch = startEpoch + WeekMath.WEEK;

        while (userEpoch <= finishedEpoch) {
            uint256 incentive = incentivesForEpoch[userEpoch];
            (uint256 userShare, uint256 totalShare) = IPFeeDistributorFactory(factory)
                .getUserAndTotalSharesAt(user, pool, userEpoch);

            userEpoch += WeekMath.WEEK;
            if (userShare == 0) continue;
            amountRewardOut += (userShare * incentive) / totalShare;
        }

        userUnclaimedEpoch[user] = userEpoch;
        if (amountRewardOut > 0) {
            IERC20(rewardToken).safeTransfer(user, amountRewardOut);
        }

        emit ClaimReward(user, rewardToken, finishedEpoch, amountRewardOut);
    }

    function _getLastFinishedEpoch() internal view virtual returns (uint256);

    function _ensureFundingValidEpoch(uint256 epoch) internal view virtual;

    uint256[100] private _gaps;
}
