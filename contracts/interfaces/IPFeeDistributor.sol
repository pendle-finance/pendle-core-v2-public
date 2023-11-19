// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPFeeDistributor {
    event UpdateFee(address indexed pool, uint256 indexed wTime, uint256 amount);

    event ClaimReward(address indexed pool, address indexed user, uint256 wTime, uint256 amount);

    event PoolAdded(address indexed pool, uint256 indexed startWeek);

    struct UserInfo {
        uint128 firstUnclaimedWeek;
        uint128 iter;
    }

    function claimReward(address user, address[] calldata pools) external returns (uint256[] memory amountRewardOut);

    function getAllPools() external view returns (address[] memory);
}
