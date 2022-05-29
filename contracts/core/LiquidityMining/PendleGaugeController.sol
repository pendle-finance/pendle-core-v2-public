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
 * @TODO: Have voting controller inherit this?
 */

/**
 * @dev Gauge controller provides no write function to any party other than voting controller
 * @dev Gauge controller will receive (lpTokens[], pendle per sec[]) from voting controller and
 * set it directly to contract state
 *
 * @dev All of the core data in this function will be set to private to prevent unintended assignments
 * on inheritting contracts
 */

abstract contract PendleGaugeController is IPGaugeController, PermissionsV2Upg {
    // this contract doesn't have mechanism to withdraw tokens out? And should we do upgradeable here?
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct PoolRewardData {
        // 4 uint256, damn. pendlePerSec is at most <= 1e18, accumulatedPendle <= 10 mil * 1e18 ...
        uint256 pendlePerSec;
        uint256 accumulatedPendle;
        uint256 accumulatedTimestamp;
        uint256 redeemedReward; // redundant variables
    }

    uint256 public constant WEEK = 1 weeks;

    address public immutable pendle;
    IPMarketFactory internal immutable marketFactory; // public

    EnumerableSet.AddressSet internal marketsIncentivized;

    uint256 private broadcastedEpochTimestamp;
    mapping(address => PoolRewardData) public rewardData;

    constructor(address _pendle, address _marketFactory) {
        pendle = _pendle;
        marketFactory = IPMarketFactory(_marketFactory);
        broadcastedEpochTimestamp = _getEpochStartTimestamp();
    }

    /**
     * @dev this function is restricted to be called by gauge only
     */
    function pullMarketReward() external {
        // should do modifier here
        address market = msg.sender;
        require(marketFactory.isValidMarket(market), "market gauge not matched"); // do we even need to verify?

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
        // hmm I don't like these kinds of asserts. We will have to evaluate cases that due to Celer stop functioning
        // the entire system is halted forever (due to permanent state mismatch)
        assert(epochStart == _getEpochStartTimestamp());
        assert(markets.length == pendleSpeeds.length);

        _finalizeLastWeekReward(); // damn, this is insane

        // different level of abstraction, that's why it's so hard to audit
        broadcastedEpochTimestamp = epochStart; // epochStart name is vague
        for (uint256 i = 0; i < markets.length; ++i) {
            address market = markets[i];
            rewardData[market].accumulatedTimestamp = epochStart;
            rewardData[market].pendlePerSec = pendleSpeeds[i];
            marketsIncentivized.add(market); // lol we shouldn't just add without checking like this, or at least we should not
        }
    }

    // previousWeek
    function _finalizeLastWeekReward() internal {
        uint256 epochStart = _getEpochStartTimestamp();
        address[] memory allMarkets = marketsIncentivized.values(); // This is super gas consuming btw, read the entire thing out
        // also, I don't think this enum set is the most gas efficient thing to use

        for (uint256 i = 0; i < allMarkets.length; ++i) {
            address market = allMarkets[i];

            PoolRewardData memory rwd = rewardData[market];
            rewardData[market].accumulatedPendle +=
                rwd.pendlePerSec *
                (epochStart - rwd.accumulatedTimestamp);
            rewardData[market].accumulatedTimestamp = epochStart;
            rewardData[market].pendlePerSec = 0;
            marketsIncentivized.remove(market); // huh wtf, remove all & re-add in?
            // this can be done much better by looping through the oldList, check if they are in the new list
            // Is it really better? Well but write then rewrite is not good as well
        }
    }

    function _updateMarketIncentives(address market) internal {
        uint256 epochStart = _getEpochStartTimestamp();

        require(broadcastedEpochTimestamp == epochStart, "votes not broadcasted");
        if (!marketsIncentivized.contains(market)) {
            // this should be moved up top so that even if vote not broadcasted, it should still run
            // what's more, we should allow a way to bypass votebroadcast and stuff in case Celer dies for an extended period of time
            // pool not listed by governance
            return;
        }

        PoolRewardData memory rwd = rewardData[market]; // just do storage is not more expensive I think
        assert(rwd.accumulatedTimestamp >= epochStart); // this should never happen

        rwd.accumulatedPendle += rwd.pendlePerSec * (block.timestamp - rwd.accumulatedTimestamp);
        rwd.accumulatedTimestamp = block.timestamp;
        rewardData[market] = rwd;
    }

    function _getEpochStartTimestamp() internal view returns (uint256) {
        return (block.timestamp / WEEK) * WEEK;
    }
}
