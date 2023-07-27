// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../libraries/math/Math.sol";
import "../libraries/BoringOwnableUpgradeable.sol";
import "../libraries/TokenHelper.sol";
import "../libraries/ArrayLib.sol";
import "../../interfaces/IPExternalRewardDistributor.sol";
import "../../interfaces/IPMarketFactory.sol";

contract PendleExternalRewardDistributor is
    IPExternalRewardDistributor,
    BoringOwnableUpgradeable,
    UUPSUpgradeable,
    TokenHelper
{
    using ArrayLib for address[];

    address public immutable marketFactory;

    modifier onlyValidMarket(address market) {
        require(IPMarketFactory(marketFactory).isValidMarket(market), "invalid market");
        _;
    }

    constructor(address _marketFactory) initializer {
        marketFactory = _marketFactory;
    }

    mapping(address => address[]) internal rewardTokens;
    mapping(address => mapping(address => MarketRewardData)) internal rewardData;

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function getRewardTokens(
        address market
    ) external view onlyValidMarket(market) returns (address[] memory) {
        return rewardTokens[market];
    }

    function _getUpdatedMarketReward(
        address token,
        address market
    ) internal view returns (MarketRewardData memory) {
        MarketRewardData memory rwd = rewardData[market][token];
        uint128 newLastUpdated = uint128(Math.min(uint128(block.timestamp), rwd.incentiveEndsAt));
        rwd.accumulatedReward += rwd.rewardPerSec * (newLastUpdated - rwd.lastUpdated);
        rwd.lastUpdated = newLastUpdated;
        return rwd;
    }

    function redeemRewards() external onlyValidMarket(msg.sender) {
        address market = msg.sender;
        address[] memory tokens = rewardTokens[market];
        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];

            rewardData[market][token] = _getUpdatedMarketReward(market, token);
            uint256 amountToDistribute = rewardData[market][token].accumulatedReward;

            if (amountToDistribute > 0) {
                rewardData[market][token].accumulatedReward = 0;
                _transferOut(token, market, amountToDistribute);
                emit DistributeReward(market, token, amountToDistribute);
            }
        }
    }

    function addRewardToMarket(
        address market,
        address token,
        uint128 rewardAmount,
        uint128 duration
    ) external onlyValidMarket(market) onlyOwner {
        MarketRewardData memory rwd = _getUpdatedMarketReward(market, token);
        require(block.timestamp + duration > rwd.incentiveEndsAt, "Invalid incentive duration");

        uint128 leftover = (rwd.incentiveEndsAt - rwd.lastUpdated) * rwd.rewardPerSec;
        uint128 newSpeed = (leftover + rewardAmount) / duration;

        rewardData[market][token] = MarketRewardData({
            rewardPerSec: newSpeed,
            accumulatedReward: rwd.accumulatedReward,
            lastUpdated: uint128(block.timestamp),
            incentiveEndsAt: uint128(block.timestamp) + duration
        });

        emit AddRewardToMarket(market, token, rewardData[market][token]);
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}
}
