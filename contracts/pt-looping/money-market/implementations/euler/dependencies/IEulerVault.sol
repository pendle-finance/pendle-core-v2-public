// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// https://github.com/euler-xyz/euler-vault-kit/blob/master/src/EVault/IEVault.sol
/// Modifications:
/// - Include `AmountCap` library in.
/// - Combine all interfaces into `IEulerVault`, and remove unused fucntions.
/// - Make the return values of `caps` function `AmountCap` for type safety.

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IEulerPriceOracle} from "./IEulerPriceOracle.sol";

type AmountCap is uint16;

uint256 constant NO_CAP = type(uint256).max;

/// @title AmountCapLib
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Library for `AmountCap` custom type
/// @dev AmountCaps are 16-bit decimal floating point values:
/// * The least significant 6 bits are the exponent
/// * The most significant 10 bits are the mantissa, scaled by 100
/// * The special value of 0 means limit is not set
///   * This is so that uninitialized storage implies no limit
///   * For an actual cap value of 0, use a zero mantissa and non-zero exponent
library AmountCapLib {
    function resolve(AmountCap self) internal pure returns (uint256) {
        uint256 amountCap = AmountCap.unwrap(self);

        if (amountCap == 0) return type(uint256).max;

        unchecked {
            // Cannot overflow because this is less than 2**256:
            //   10**(2**6 - 1) * (2**10 - 1) = 1.023e+66
            return 10 ** (amountCap & 63) * (amountCap >> 6) / 100;
        }
    }

    function toRawUint16(AmountCap self) internal pure returns (uint16) {
        return AmountCap.unwrap(self);
    }
}

using AmountCapLib for AmountCap global;

interface IEulerVault is IERC4626 {
    /// @notice Debt owed by a particular account, in underlying units
    /// @param account Address to query
    /// @return The debt of the account in asset units
    function debtOf(address account) external view returns (uint256);

    /// @notice Transfer underlying tokens from the vault to the sender, and increase sender's debt
    /// @param amount Amount of assets to borrow (use max uint256 for all available tokens)
    /// @param receiver Account receiving the borrowed tokens
    /// @return Amount of assets borrowed
    function borrow(uint256 amount, address receiver) external returns (uint256);

    /// @notice Transfer underlying tokens from the sender to the vault, and decrease receiver's debt
    /// @param amount Amount of debt to repay in assets (use max uint256 for full debt)
    /// @param receiver Account holding the debt to be repaid
    /// @return Amount of assets repaid
    function repay(uint256 amount, address receiver) external returns (uint256);

    /// @notice Enables balance forwarding for the authenticated account
    /// @dev Only the authenticated account can enable balance forwarding for itself
    /// @dev Should call the IBalanceTracker hook with the current account's balance
    function enableBalanceForwarder() external;

    // View

    /// @notice Balance of vault assets as tracked by deposits/withdrawals and borrows/repays
    /// @return The amount of assets the vault tracks as current direct holdings
    function cash() external view returns (uint256);

    /// @notice Retrieves supply and borrow caps
    /// @return supplyCap The supply cap
    /// @return borrowCap The borrow cap
    function caps() external view returns (AmountCap supplyCap, AmountCap borrowCap);

    /// @notice Retrieves LTV configuration for the collateral
    /// @param collateral Collateral asset
    /// @return borrowLTV The current value of borrow LTV for originating positions
    /// @return liquidationLTV The value of fully converged liquidation LTV
    /// @return initialLiquidationLTV The initial value of the liquidation LTV, when the ramp began
    /// @return targetTimestamp The timestamp when the liquidation LTV is considered fully converged
    /// @return rampDuration The time it takes for the liquidation LTV to converge from the initial value to the fully
    /// converged value
    function LTVFull(IEulerVault collateral)
        external
        view
        returns (
            uint256 borrowLTV,
            uint256 liquidationLTV,
            uint256 initialLiquidationLTV,
            uint256 targetTimestamp,
            uint256 rampDuration
        );

    function LTVList() external view returns (IEulerVault[] memory);

    /// @notice Retrieves the address of the oracle contract
    /// @return The address of the oracle
    function oracle() external view returns (IEulerPriceOracle);

    /// @notice Retrieves the current interest rate for an asset
    /// @return The interest rate in yield-per-second, scaled by 10**27
    function interestRate() external view returns (uint256);
    /// @notice Sum of all outstanding debts, in underlying units (increases as interest is accrued)
    /// @return The total borrows in asset units
    function totalBorrows() external view returns (uint256);
    /// @notice Retrieves the interest fee in effect for the vault
    /// @return Amount of interest that is redirected as a fee, as a fraction scaled by 1e4
    function interestFee() external view returns (uint16);

    /// @notice Retrieves a reference asset used for liquidity calculations
    /// @return The address of the reference asset
    function unitOfAccount() external view returns (address);

    /// @notice Looks up an asset's currently configured interest rate model
    /// @return Address of the interest rate contract or address zero to indicate 0% interest
    function interestRateModel() external view returns (address);

    /// @notice Checks to see if a liquidation would be profitable, without actually doing anything
    /// @param liquidator Address that will initiate the liquidation
    /// @param violator Address that may be in collateral violation
    /// @param collateral Collateral which is to be seized
    /// @return maxRepay Max amount of debt that can be repaid, in asset units
    /// @return maxYield Yield in collateral corresponding to max allowed amount of debt to be repaid, in collateral
    /// balance (shares for vaults)
    function checkLiquidation(address liquidator, address violator, IEulerVault collateral)
        external
        view
        returns (uint256 maxRepay, uint256 maxYield);

    /// @notice Attempts to perform a liquidation
    /// @param violator Address that may be in collateral violation
    /// @param collateral Collateral which is to be seized
    /// @param repayAssets The amount of underlying debt to be transferred from violator to sender, in asset units (use
    /// max uint256 to repay the maximum possible amount).
    /// @param minYieldBalance The minimum acceptable amount of collateral to be transferred from violator to sender, in
    /// collateral balance units (shares for vaults)
    function liquidate(address violator, IEulerVault collateral, uint256 repayAssets, uint256 minYieldBalance) external;

    /// @notice Retrieves liquidation cool-off time, which must elapse after successful account status check before
    /// account can be liquidated
    /// @return The liquidation cool off time in seconds
    function liquidationCoolOffTime() external view returns (uint16);
}
