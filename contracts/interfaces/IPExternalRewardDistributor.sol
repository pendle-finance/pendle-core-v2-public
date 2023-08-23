// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPExternalRewardDistributor {
    struct MarketRewardData {
        uint128 rewardPerSec;
        uint128 accumulatedReward;
        uint128 lastUpdated;
        uint128 incentiveEndsAt;
    }

    event DistributeReward(address indexed market, address indexed rewardToken, uint256 amount);

    event AddRewardToMarket(address indexed market, address indexed token, MarketRewardData data);

    function getRewardTokens(address market) external view returns (address[] memory);

    function redeemRewards() external;
}
