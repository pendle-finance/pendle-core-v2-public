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
import "../../core/libraries/ArrayLib.sol";

contract PendleFeeDistributor is UUPSUpgradeable, BoringOwnableUpgradeable, IPFeeDistributor {
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;

    address public immutable votingController;
    address public immutable vePendle;
    address public immutable token;

    // [pool] => lastFundedWeek
    mapping(address => uint256) public lastFundedWeek;

    // [pool] => startTime
    mapping(address => uint256) public startWeek;

    // [pool, user] => UserInfo
    mapping(address => mapping(address => UserInfo)) public userInfo;

    // [pool, epoch] => [fee]
    mapping(address => mapping(uint256 => uint256)) public fees;

    modifier ensureValidPool(address pool) {
        if (startWeek[pool] == 0) revert Errors.FDInvalidPool(pool);
        _;
    }

    constructor(
        address _votingController,
        address _vePendle,
        address _rewardToken
    ) initializer {
        votingController = _votingController;
        vePendle = _vePendle;
        token = _rewardToken;
    }

    function addPool(address pool, uint256 _startWeek) external onlyOwner {
        if (!WeekMath.isValidWTime(_startWeek) || _startWeek == 0)
            revert Errors.FDInvalidStartEpoch(_startWeek);
        if (startWeek[pool] != 0) revert Errors.FDPoolAlreadyExists(pool, startWeek[pool]);

        startWeek[pool] = _startWeek;
        lastFundedWeek[pool] = _startWeek - WeekMath.WEEK;
    }

    function fund(
        address pool,
        uint256[] calldata wTimes,
        uint256[] calldata amounts
    ) external ensureValidPool(pool) {
        if (wTimes.length != amounts.length) revert Errors.FDEpochLengthMismatch();

        uint256 totalRewardFunding = 0;
        for (uint256 i = 0; i < amounts.length; ++i) {
            uint256 wTime = wTimes[i];
            uint256 amount = amounts[i];

            if (!WeekMath.isValidWTime(wTime)) revert Errors.InvalidWTime(wTime);

            fees[pool][wTime] += amount;
            totalRewardFunding += amount;

            emit Fund(pool, wTime, amount);
        }

        IERC20(token).transferFrom(msg.sender, address(this), totalRewardFunding);
        lastFundedWeek[pool] = ArrayLib.max(wTimes);
    }

    function claimReward(address user, address[] calldata pools)
        external
        returns (uint256 amountRewardOut)
    {
        for (uint256 i = 0; i < pools.length; ) {
            amountRewardOut += _accumulateUserReward(pools[i], user);
            unchecked {
                i++;
            }
        }
        IERC20(token).safeTransfer(user, amountRewardOut);
    }

    function _accumulateUserReward(address pool, address user)
        internal
        ensureValidPool(pool)
        returns (uint256 totalReward)
    {
        uint256 fundedWeek = lastFundedWeek[pool];
        uint256 wTime = userInfo[pool][user].wTime;
        uint256 iter = userInfo[pool][user].iter;

        if (wTime > fundedWeek) return 0;
        if (wTime == 0) wTime = startWeek[pool];

        uint256 length = _getUserCheckpointLength(pool, user);
        if (length == 0) {
            userInfo[pool][user].wTime = uint128(fundedWeek);
            return 0;
        }

        Checkpoint memory checkpoint = _getUserCheckpointAt(pool, user, iter);
        Checkpoint memory nextCheckpoint;

        while (wTime <= fundedWeek) {
            if (iter + 1 < length) {
                // We have at most 1 checkpoint per week, so while loop is not needed
                if (nextCheckpoint.timestamp <= checkpoint.timestamp) {
                    nextCheckpoint = _getUserCheckpointAt(pool, user, iter + 1);
                }
                if (nextCheckpoint.timestamp < wTime) {
                    iter++;
                    checkpoint = nextCheckpoint;
                }
            }

            if (checkpoint.timestamp < wTime) {
                uint256 userShare = checkpoint.value.getValueAt(uint128(wTime));
                uint256 totalShare = _getPoolTotalSharesAt(pool, uint128(wTime));
                if (userShare > 0) {
                    uint256 amountRewardOut = (userShare * fees[pool][wTime]) / totalShare;
                    totalReward += amountRewardOut;
                    emit ClaimReward(pool, user, wTime, amountRewardOut);
                }
            }
            wTime += WeekMath.WEEK;
        }

        userInfo[pool][user] = UserInfo({ wTime: uint128(wTime), iter: uint128(iter) });
    }

    function _getPoolTotalSharesAt(address pool, uint128 wTime) internal view returns (uint256) {
        if (pool == vePendle) {
            return IPVotingEscrowMainchain(vePendle).totalSupplyAt(wTime);
        } else {
            return IPVotingController(votingController).getPoolTotalVoteAt(pool, wTime);
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
