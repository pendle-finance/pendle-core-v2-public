// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISolvOracle {
    function setSubscribeNavOnlyMarket(bytes32 poolId_, uint256 time_, uint256 nav_) external;
    function updateAllTimeHighRedeemNavOnlyMarket(bytes32 poolId_, uint256 nav_) external;
    function getSubscribeNav(bytes32 poolId_, uint256 time_) external view returns (uint256 nav_, uint256 navTime_);
    function getAllTimeHighRedeemNav(bytes32 poolId_) external view returns (uint256);
}
