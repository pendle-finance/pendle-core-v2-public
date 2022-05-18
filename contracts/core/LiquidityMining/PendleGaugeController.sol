// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPGaugeController.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../libraries/math/Math.sol";
import "../../interfaces/IPGauge.sol";
import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPMarketFactory.sol";
import "../../periphery/PermissionsV2Upg.sol";

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

    struct PoolRewardData {
        uint256 pendlePerSec;
        uint256 accumulatedPendle;
        uint256 accumulatedTimestamp;
        uint256 redeemedReward;
    }

    uint256 public constant WEEK = 1 weeks;

    address public immutable pendle;
    IPMarketFactory internal immutable marketFactory;

    uint256 private broadcastedEpochTimestamp;
    mapping(address => bool) public poolListed;
    mapping(address => PoolRewardData) public rewardData;

    constructor(address _pendle, address _marketFactory) {
        pendle = _pendle;
        marketFactory = IPMarketFactory(_marketFactory);
    }

    function updateAndGetMarketIncentives(address market) public returns (uint256) {
        if (!poolListed[market]) {
            // pool not listed by governance
            return rewardData[market].accumulatedPendle;
        }

        uint256 currentTimestamp = block.timestamp;
        uint256 epochStart = (currentTimestamp / WEEK) * WEEK;
        require(broadcastedEpochTimestamp == epochStart, "votes not broadcasted");

        PoolRewardData memory rwd = rewardData[market];
        assert(rwd.accumulatedTimestamp >= epochStart); // this should never happen

        rwd.accumulatedPendle += rwd.pendlePerSec * (currentTimestamp - rwd.accumulatedTimestamp);
        rwd.accumulatedTimestamp = currentTimestamp;
        rewardData[market] = rwd;
        return rwd.accumulatedPendle;
    }

    /**
     * @dev this function is restricted to be called by gauge only
     */
    function redeemLpStakerReward(address staker, uint256 amount) external {
        address gauge = msg.sender;
        address market = IPGauge(gauge).market();
        require(marketFactory.verifyGauge(market, gauge), "market gauge not matched");
        if (amount != 0) {
            rewardData[market].accumulatedPendle -= amount;
            IERC20(pendle).safeTransfer(staker, amount);
        }
    }

    function listPool(address market) external onlyGovernance {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "invalid market");
        poolListed[market] = true;
    }

    function unlistPool(address market) external onlyGovernance {
        require(poolListed[market], "market not listed");
        poolListed[market] = false;
    }

    // @TODO Think of what solution there is when these assert actually fails
    function _receiveVotingResults(
        uint256 epochStart,
        address[] memory markets,
        uint256[] memory pendleSpeeds
    ) internal {
        assert(epochStart == (block.timestamp / WEEK) * WEEK);
        assert(markets.length == pendleSpeeds.length);
        broadcastedEpochTimestamp = epochStart;
        for (uint256 i = 0; i < markets.length; ++i) {
            address market = markets[i];
            assert(poolListed[market]);

            PoolRewardData memory rwd = rewardData[market];
            if (rwd.accumulatedTimestamp == 0) {
                rewardData[market].accumulatedTimestamp = epochStart;
                rewardData[market].pendlePerSec = pendleSpeeds[i];
                continue;
            }

            assert(rwd.accumulatedTimestamp < epochStart);
            assert(epochStart - rwd.accumulatedTimestamp <= WEEK);

            rewardData[market].accumulatedPendle +=
                rwd.pendlePerSec *
                (epochStart - rwd.accumulatedTimestamp);
            rewardData[market].pendlePerSec = pendleSpeeds[i];
            rewardData[market].accumulatedTimestamp = epochStart;
        }
    }
}
