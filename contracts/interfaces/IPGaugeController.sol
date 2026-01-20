// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPGaugeController {
    event MarketClaimReward(address indexed market, uint256 amount);

    // deprecated from MarketV7 onwards
    event ReceiveVotingResults(uint128 indexed wTime, address[] markets, uint256[] pendleAmounts);

    // deprecated from MarketV7 onwards
    event UpdateMarketReward(address indexed market, uint256 pendlePerSec, uint256 incentiveEndsAt);

    event UpdateMarketRewardV2(address indexed market, uint128 pendlePerSec, uint128 incentiveEndsAt);

    function setRewardDatas(
        address[] calldata markets,
        uint128[] calldata pendlePerSecs,
        uint128[] calldata incentiveEndsAts
    ) external;

    function withdrawPendle(uint256 amount) external;

    function pendle() external view returns (address);

    function redeemMarketReward() external;

    function rewardData(
        address market
    )
        external
        view
        returns (uint128 pendlePerSec, uint128 accumulatedPendle, uint128 lastUpdated, uint128 incentiveEndsAt);
}
