// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface ISAvax {
    function decimals() external pure returns (uint8);

    function balanceOf(address account) external view returns (uint256);

    function totalPooledAvax() external returns (uint256);

    function totalShares() external returns (uint256);

    /**
     * @return The amount of AVAX that corresponds to `shareAmount` sAVAX token shares.
     */
    function getPooledAvaxByShares(uint256 shareAmount) external view returns (uint256);

    function cooldownPeriod() external returns (uint256);

    function redeemPeriod() external returns (uint256);

    /**
     * @notice Process user deposit, mints liquid tokens and increase the pool buffer -> Will be called when NATIVE AVAX is transferred to SAVAX (Dont need to call this function explicitly)
     * @return Amount of sAVAX shares generated
     */
    function submit() external payable returns (uint256);

    /**
     * @notice Redeem all redeemable AVAX from all unlocks
     */
    function redeem() external;

    /**
     * @notice Redeem AVAX after cooldown has finished
     * @param unlockIndex Index number of the redeemed unlock request
     */
    function redeem(uint256 unlockIndex) external;

    /**
     * @notice Redeem all sAVAX held in custody for overdue unlock requests
     */
    function redeemOverdueShares() external;

    /**
     * @notice Redeem sAVAX held in custody for the given unlock request
     * @param unlockIndex Unlock request array index
     */
    function redeemOverdueShares(uint256 unlockIndex) external;

    /**
     * @notice Start unlocking cooldown period for `shareAmount` AVAX
     * @param shareAmount Amount of shares to unlock
     */
    function requestUnlock(uint256 shareAmount) external;

    /**
     * @notice Get the number of active unlock requests by user
     * @param user User address
     */
    function getUnlockRequestCount(address user) external view returns (uint256);
}
