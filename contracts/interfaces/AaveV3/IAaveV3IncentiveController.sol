// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IAaveV3IncentiveController {
    function getRewardsList() external view returns (address[] memory);

    function claimAllRewardsToSelf(
        address[] calldata assets
    ) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}
