// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISJoe {
    function joe() external view returns (address);

    function depositFeePercent() external view returns (uint256);

    function internalJoeBalance() external view returns (uint256);

    /**
     * @notice Deposit JOE for reward token allocation
     * @param _amount The amount of JOE to deposit
     */
    function deposit(uint256 _amount) external;

    /**
     * @notice Get user info
     * @param _user The address of the user
     * @param _rewardToken The address of the reward token
     * @return The amount of JOE user has deposited
     * @return The reward debt for the chosen token
     */
    function getUserInfo(address _user, IERC20 _rewardToken)
        external
        view
        returns (uint256, uint256);

    /**
     * @notice Get the number of reward tokens
     * @return The length of the array
     */
    function rewardTokensLength() external view returns (uint256);

    function rewardTokens(uint256 _index) external view returns (address);

    /**
     * @notice View function to see pending reward token on frontend
     * @param _user The address of the user
     * @param _token The address of the token
     * @return `_user`'s pending reward token
     */
    function pendingReward(address _user, IERC20 _token) external view returns (uint256);

    /**
     * @notice Withdraw JOE and harvest the rewards
     * @param _amount The amount of JOE to withdraw
     */
    function withdraw(uint256 _amount) external;

    /**
     * @notice Withdraw without caring about rewards. EMERGENCY ONLY
     */
    function emergencyWithdraw() external;
}
