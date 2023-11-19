// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface ISiloIncentiveController {
    /**
     * @dev Claims reward for msg.sender, on all the assets of the lending pool, accumulating the pending rewards
     * @param amount Amount of rewards to claim
     * @return Rewards claimed
     */
    function claimRewardsToSelf(address[] calldata assets, uint256 amount) external returns (uint256);

    /**
     * @dev for backward compatibility with previous implementation of the Incentives controller
     */
    function REWARD_TOKEN() external view returns (address); // solhint-disable-line func-name-mixedcase
}
