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
    mapping(address => mapping(address => RewardData)) internal rewardDatas;

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function getRewardTokens(
        address market
    ) external view onlyValidMarket(market) returns (address[] memory) {
        return rewardTokens[market];
    }

    function redeemRewards() external onlyValidMarket(msg.sender) {
        address market = msg.sender;
        address[] memory tokens = rewardTokens[market];
        for (uint256 i = 0; i < tokens.length; ++i) {
            address token = tokens[i];
            RewardData memory data = rewardDatas[market][token];

            if (data.lastDistributedTime >= data.endTime) {
                continue;
            }

            uint256 distributeFrom = Math.max(data.lastDistributedTime, data.startTime);
            uint256 distributeTo = Math.min(block.timestamp, data.endTime);

            if (distributeTo < distributeFrom) {
                continue;
            }

            uint256 amountToDistribute = (distributeTo - distributeFrom) * data.rewardPerSec;

            data.lastDistributedTime = uint32(block.timestamp);
            rewardDatas[market][token] = data;

            _transferOut(token, market, amountToDistribute);

            emit DistributeReward(market, token, amountToDistribute);
        }
    }

    function setRewardData(
        address market,
        address token,
        uint160 rewardPerSec,
        uint32 startTime,
        uint32 endTime
    ) external onlyValidMarket(market) onlyOwner {
        RewardData memory data = rewardDatas[market][token];
        if (startTime != data.startTime) {
            require(data.endTime < block.timestamp, "Previous reward batch not ended");
        }

        data.rewardPerSec = rewardPerSec;
        data.startTime = startTime;
        data.endTime = endTime;
        rewardDatas[market][token] = data;

        if (!rewardTokens[market].contains(token)) {
            rewardTokens[market].push(token);
        }
        emit SetRewardData(market, token, data);
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}
}
