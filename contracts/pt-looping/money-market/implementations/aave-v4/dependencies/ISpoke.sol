// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IHubBase} from "./IHubBase.sol";

/// https://github.com/aave/aave-v4/blob/main/src/spoke/interfaces/ISpoke.sol
/// Modifications:
/// - Trimmed to the structs and functions actually used by EulerMoneyMarket/View's Aave V4
///   equivalent (initialize/lend/borrow/repay/withdraw/collateralBalance/debtBalance/oracle rate,
///   plus thresholds/liquidity view queries). Governance, liquidation, and position-manager
///   surfaces are intentionally omitted -- not called by this money market.
interface ISpoke {
    struct Reserve {
        address underlying;
        IHubBase hub;
        uint16 assetId;
        uint8 decimals;
        uint24 collateralRisk;
        uint8 flags;
        uint32 dynamicConfigKey;
    }

    struct DynamicReserveConfig {
        uint16 collateralFactor;
        uint32 maxLiquidationBonus;
        uint16 liquidationFee;
    }

    struct UserPosition {
        uint120 drawnShares;
        uint120 premiumShares;
        int200 premiumOffsetRay;
        uint120 suppliedShares;
        uint32 dynamicConfigKey;
    }

    /// @notice Address of this Spoke's oracle. Public immutable on the real contract (auto-getter).
    function ORACLE() external view returns (address);

    /// @notice Supplies `amount` of the reserve's underlying, crediting `onBehalfOf`.
    /// @dev Caller must be `onBehalfOf` or an approved position manager for it -- `msg.sender ==
    /// onBehalfOf` always satisfies this with zero registration, which is the only case we use.
    /// @return shares, assets (assets is `amount` echoed back, not a rounded conversion).
    function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @return shares, assets actually withdrawn.
    function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @return shares, assets actually borrowed (echoed back, not rounded).
    function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @return shares, total debt value restored. This is always exactly `min(amount, totalDebt)`:
    /// `UserPositionUtils.calculateRestoreAmount` splits `amount` into drawn and premium components
    /// whose sum reconstitutes `amount` exactly (or the full debt, when `amount` covers it), and
    /// `Spoke.repay` pulls precisely that sum from `msg.sender`. It can never exceed the input, so
    /// callers may rely on `repaid <= debtBefore` without a saturating subtraction.
    function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);

    /// @notice Enables/disables `reserveId` as collateral for `onBehalfOf`.
    function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral, address onBehalfOf) external;

    /// @notice Reverts if the reserve associated with `reserveId` is not listed.
    function getReserve(uint256 reserveId) external view returns (Reserve memory);

    /// @notice Reverts if `reserveId` is not listed; does not revert if `dynamicConfigKey` is unset.
    function getDynamicReserveConfig(uint256 reserveId, uint32 dynamicConfigKey)
        external
        view
        returns (DynamicReserveConfig memory);

    /// @notice Assets supplied by `user` for `reserveId`, already resolved from shares to assets.
    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);

    /// @notice Total debt (drawn + risk-premium components already summed) owed by `user` for `reserveId`.
    function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);

    /// @notice Per-user, per-reserve position data. `dynamicConfigKey` here is the config version
    /// actually pinned to this position -- it can lag `Reserve.dynamicConfigKey` (the reserve's
    /// current version) until the position's next `borrow`/`withdraw`/`setUsingAsCollateral(true)`
    /// refreshes it. Use this, not `getReserve(...).dynamicConfigKey`, to read the config that's
    /// actually enforced for a given position (verified against `Spoke._processUserAccountData`).
    function getUserPosition(uint256 reserveId, address user) external view returns (UserPosition memory);

    /// @notice The risk premium from `user`'s last position update, in BPS -- a per-position
    /// surcharge on top of the reserve's base drawn rate, based on the quality of the collateral
    /// backing their debt. Not reflected in `getAssetDrawnRate`, which is Hub-wide/market-level.
    function getUserLastRiskPremium(address user) external view returns (uint256);
}
