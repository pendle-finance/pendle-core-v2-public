// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../core-libraries/math/Math.sol";
import "../../core-libraries/Errors.sol";
import "../../core-libraries/BoringOwnableUpgradeable.sol";

import "../libraries/WeekMath.sol";

import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev Gauge controller provides no write function to any party other than voting controller
 * @dev Gauge controller will receive (lpTokens[], pendle per sec[]) from voting controller and
 * set it directly to contract state
 *
 * @dev All of the core data in this function will be set to private to prevent unintended assignments
 * on inheriting contracts
 */

/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract PendleGaugeControllerBaseUpg is IPGaugeController, BoringOwnableUpgradeable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct MarketRewardData {
        uint128 pendlePerSec;
        uint128 accumulatedPendle;
        uint128 lastUpdated;
        uint128 incentiveEndsAt;
    }

    uint128 internal constant WEEK = 1 weeks;

    address public immutable pendle;
    IPMarketFactory public immutable marketFactory;

    mapping(address => MarketRewardData) public rewardData;
    mapping(uint128 => bool) public epochRewardReceived;

    uint256[100] private __gap;

    modifier onlyPendleMarket() {
        if (!marketFactory.isValidMarket(msg.sender)) revert Errors.GCNotPendleMarket(msg.sender);
        _;
    }

    constructor(address _pendle, address _marketFactory) {
        pendle = _pendle;
        marketFactory = IPMarketFactory(_marketFactory);
    }

    /**
     * @notice claim the rewards allocated by gaugeController
     * @dev pre-condition: onlyPendleMarket can call it
     * @dev state changes expected:
        - rewardData[market] is updated with the data up to now
        - all accumulatedPendle is transferred out & the accumulatedPendle is set to 0
     */
    function redeemMarketReward() external onlyPendleMarket {
        address market = msg.sender;
        rewardData[market] = _getUpdatedMarketReward(market);

        uint256 amount = rewardData[market].accumulatedPendle;
        if (amount != 0) {
            rewardData[market].accumulatedPendle = 0;
            IERC20(pendle).safeTransfer(market, amount);
        }

        emit MarketClaimReward(market, amount);
    }

    function fundPendle(uint256 amount) external {
        IERC20(pendle).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdrawPendle(uint256 amount) external onlyOwner {
        IERC20(pendle).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice receive voting results from VotingController. Can handle duplicated messages fine by only accepting the first
     message for that timestamp
     * @dev state changes expected:
        - epochRewardReceived is marked as true
        - rewardData is updated for all markets in markets[]
     */
    function _receiveVotingResults(
        uint128 wTime,
        address[] memory markets,
        uint256[] memory pendleAmounts
    ) internal {
        if (markets.length != pendleAmounts.length) revert Errors.ArrayLengthMismatch();

        if (epochRewardReceived[wTime]) return; // only accept the first message for the wTime
        epochRewardReceived[wTime] = true;

        for (uint256 i = 0; i < markets.length; ++i) {
            if (!IPMarket(markets[i]).isExpired())
                _addRewardsToMarket(markets[i], pendleAmounts[i].Uint128());
        }

        emit ReceiveVotingResults(wTime, markets, pendleAmounts);
    }

    /**
     * @notice merge the additional rewards with the existing rewards
     * @dev this function will calc the total amount of Pendle that hasn't been factored into accumulatedPendle yet,
        combined them with the additional pendleAmount, then divide them equally over the next one week
     * @dev expected state changes:
        - rewardData of the market is updated
     */
    function _addRewardsToMarket(address market, uint128 pendleAmount) internal {
        MarketRewardData memory rwd = _getUpdatedMarketReward(market);
        uint128 leftover = (rwd.incentiveEndsAt - rwd.lastUpdated) * rwd.pendlePerSec;
        uint128 newSpeed = (leftover + pendleAmount) / WEEK;

        rewardData[market] = MarketRewardData({
            pendlePerSec: newSpeed,
            accumulatedPendle: rwd.accumulatedPendle,
            lastUpdated: uint128(block.timestamp),
            incentiveEndsAt: uint128(block.timestamp) + WEEK
        });
    }

    /**
     * @notice get the updated state of the market, to the current time with all the undistributed Pendle distributed to the
        accumulatedPendle
     * @dev expect to update accumulatedPendle & lastUpdated in MarketRewardData
     */
    function _getUpdatedMarketReward(address market)
        internal
        view
        returns (MarketRewardData memory)
    {
        MarketRewardData memory rwd = rewardData[market];
        uint128 newLastUpdated = uint128(Math.min(uint128(block.timestamp), rwd.incentiveEndsAt));
        rwd.accumulatedPendle += rwd.pendlePerSec * (newLastUpdated - rwd.lastUpdated);
        rwd.lastUpdated = newLastUpdated;
        return rwd;
    }
}
