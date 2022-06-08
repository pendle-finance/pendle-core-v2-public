// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../../interfaces/IPGaugeController.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../libraries/math/Math.sol";
import "../../../libraries/math/WeekMath.sol";
import "../../../interfaces/IPGaugeController.sol";
import "../../../interfaces/IPMarketFactory.sol";
import "../../../periphery/PermissionsV2Upg.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @TODO: Have voting controller inherit this?
 */

/**
 * @dev Gauge controller provides no write function to any party other than voting controller
 * @dev Gauge controller will receive (lpTokens[], pendle per sec[]) from voting controller and
 * set it directly to contract state
 *
 * @dev All of the core data in this function will be set to private to prevent unintended assignments
 * on inheritting contracts
 *
 * @dev no more pause
 */

abstract contract PendleGaugeController is IPGaugeController, PermissionsV2Upg {
    // this contract doesn't have mechanism to withdraw tokens out? And should we do upgradeable here?
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct MarketRewardData {
        // 4 uint256, damn. pendlePerSec is at most <= 1e18, accumulatedPendle <= 10 mil * 1e18 ...
        uint128 pendlePerSec;
        uint128 accumulatedPendle;
        uint128 accumulatedTimestamp;
        uint128 incentiveEndsAt;
    }

    uint128 public constant WEEK = 1 weeks;

    address public immutable pendle;
    IPMarketFactory internal immutable marketFactory; // public

    uint256 private broadcastedEpochTimestamp;
    mapping(address => MarketRewardData) public rewardData;
    mapping(uint128 => bool) internal epochRewardReceived;

    modifier onlyMarket() {
        require(marketFactory.isValidMarket(msg.sender), "invalid market");
        _;
    }

    constructor(address _pendle, address _marketFactory) {
        pendle = _pendle;
        marketFactory = IPMarketFactory(_marketFactory);
        broadcastedEpochTimestamp = WeekMath.getCurrentWeekStart();
    }

    /**
     * @dev this function is restricted to be called by gauge only
     */
    function claimMarketReward() external onlyMarket {
        // should do modifier here
        address market = msg.sender;
        updateMarketData(market);

        uint256 amount = rewardData[market].accumulatedPendle;
        if (amount != 0) {
            rewardData[market].accumulatedPendle = 0;
            IERC20(pendle).safeTransfer(market, amount);
        }
    }

    function fundPendle(uint256 amount) external onlyGovernance {
        IERC20(pendle).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdrawPendle(uint256 amount) external onlyGovernance {
        IERC20(pendle).safeTransfer(msg.sender, amount);
    }

    function updateMarketData(address market) public {
        rewardData[market] = _getUpdatedMarketData(market);
    }

    function _getUpdatedMarketData(address market)
        internal
        view
        returns (MarketRewardData memory)
    {
        MarketRewardData memory rwd = rewardData[market]; // just do storage is not more expensive I think
        uint128 newAccumulatedTimestamp = uint128(
            Math.min(uint128(block.timestamp), rwd.incentiveEndsAt)
        );
        rwd.accumulatedPendle +=
            rwd.pendlePerSec *
            (newAccumulatedTimestamp - rwd.accumulatedTimestamp);
        rwd.accumulatedTimestamp = newAccumulatedTimestamp;
        return rwd;
    }

    // @TODO Think of what solution there is when these assert actually fails
    function _receiveVotingResults(
        uint128 timestamp,
        address[] memory markets,
        uint256[] memory incentives
    ) internal {
        if (epochRewardReceived[timestamp]) return;
        require(markets.length == incentives.length, "invalid markets length");

        for (uint256 i = 0; i < markets.length; ++i) {
            _incentivizeMarket(markets[i], uint128(incentives[i]));
        }
        epochRewardReceived[timestamp] = true;
    }

    function _incentivizeMarket(address market, uint128 amount) internal {
        MarketRewardData memory rwd = _getUpdatedMarketData(market);
        uint128 leftover = (rwd.incentiveEndsAt - rwd.accumulatedTimestamp) * rwd.pendlePerSec;
        uint128 newSpeed = (leftover + amount) / WEEK;
        rewardData[market] = MarketRewardData({
            pendlePerSec: newSpeed,
            accumulatedPendle: rwd.accumulatedPendle,
            accumulatedTimestamp: uint128(block.timestamp),
            incentiveEndsAt: uint128(block.timestamp) + WEEK
        });
    }
}
