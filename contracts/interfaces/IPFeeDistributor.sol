// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPFeeDistributor {
    event Fund(address indexed pool, uint256 indexed wTime, uint256 amount);

    event ClaimReward(address indexed pool, address indexed user, uint256 wTime, uint256 amount);

    struct UserInfo {
        uint128 wTime; // Last accounted epoch for each user
        uint128 iter;
    }

    function claimReward(address user, address[] calldata pools)
        external
        returns (uint256[] memory amountRewardOut);
}
