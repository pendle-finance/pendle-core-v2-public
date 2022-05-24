// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPGaugeController.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../libraries/math/Math.sol";
import "../../interfaces/IPGauge.sol";
import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPMarketFactory.sol";
import "../../periphery/PermissionsV2Upg.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @dev Gauge controller provides no write function to any party other than voting controller
 * @dev Gauge controller will receive (lpTokens[], pendle per sec[]) from voting controller and
 * set it directly to contract state
 *
 * @dev All of the core data in this function will be set to private to prevent unintended assignments
 * on inheritting contracts
 */

abstract contract PendleGaugeController is IPGaugeController, PermissionsV2Upg {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct PoolRewardData {
        uint256 pendlePerSec;
        uint256 accumulatedPendle;
        uint256 accumulatedTimestamp;
        uint256 redeemedReward;
    }

    uint256 public constant WEEK = 1 weeks;

    address public immutable pendle;
    uint256 internal immutable startWeek;
    IPMarketFactory internal immutable marketFactory;

    EnumerableSet.AddressSet internal marketsIncentivized;

    uint256 private broadcastedEpochTimestamp;
    mapping(address => PoolRewardData) public rewardData;

    constructor(address _pendle, address _marketFactory) {
        pendle = _pendle;
        marketFactory = IPMarketFactory(_marketFactory);
        startWeek = _getEpochStartTimestamp();
    }

    /**
     * @dev this function is restricted to be called by gauge only
     */
    function pullMarketReward() external {
        address market = msg.sender;
        require(marketFactory.isValidMarket(market), "market gauge not matched");

        _updateMarketIncentives(market);
        uint256 amount = rewardData[market].accumulatedPendle;
        if (amount != 0) {
            rewardData[market].accumulatedPendle = 0;
            IERC20(pendle).safeTransfer(market, amount);
        }
    }

    // @TODO Think of what solution there is when these assert actually fails
    function _receiveVotingResults(
        uint256 epochStart,
        address[] memory markets,
        uint256[] memory pendleSpeeds
    ) internal {
        assert(epochStart == _getEpochStartTimestamp());
        assert(markets.length == pendleSpeeds.length);

        _finalizeLastWeekReward();

        broadcastedEpochTimestamp = epochStart;
        for (uint256 i = 0; i < markets.length; ++i) {
            address market = markets[i];
            rewardData[market].accumulatedTimestamp = epochStart;
            rewardData[market].pendlePerSec = pendleSpeeds[i];
            marketsIncentivized.add(market);
        }
    }

    function _finalizeLastWeekReward() internal {
        uint256 epochStart = _getEpochStartTimestamp();
        address[] memory allMarkets = marketsIncentivized.values();
        for (uint256 i = 0; i < allMarkets.length; ++i) {
            address market = allMarkets[i];

            PoolRewardData memory rwd = rewardData[market];
            rewardData[market].accumulatedPendle +=
                rwd.pendlePerSec *
                (epochStart - rwd.accumulatedTimestamp);
            rewardData[market].accumulatedTimestamp = epochStart;
            rewardData[market].pendlePerSec = 0;
            marketsIncentivized.remove(market);
        }
    }

    function _updateMarketIncentives(address market) internal {
        uint256 epochStart = _getEpochStartTimestamp();

        if (epochStart != startWeek) {
            require(broadcastedEpochTimestamp == epochStart, "votes not broadcasted");
        }
        if (!marketsIncentivized.contains(market)) {
            // pool not listed by governance
            return;
        }

        PoolRewardData memory rwd = rewardData[market];
        assert(rwd.accumulatedTimestamp >= epochStart); // this should never happen

        rwd.accumulatedPendle += rwd.pendlePerSec * (block.timestamp - rwd.accumulatedTimestamp);
        rwd.accumulatedTimestamp = block.timestamp;
        rewardData[market] = rwd;
    }

    function _getEpochStartTimestamp() internal view returns (uint256) {
        return (block.timestamp / WEEK) * WEEK;
    }
}
