// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPFeeDistributor {
    event Fund(address indexed pool, uint256 indexed epoch, uint256 incentive);

    event ClaimReward(
        address indexed pool,
        address indexed user,
        uint256 epoch,
        uint256 amountReward
    );

    struct UserInfo {
        uint128 epoch; // Last accounted epoch for each user
        uint128 iter;
    }

    function claimReward(address user, address[] calldata pools)
        external
        returns (uint256 amountRewardOut);
}
