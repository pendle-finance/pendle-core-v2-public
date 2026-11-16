// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/// https://github.com/aave/aave-v4/blob/main/src/hub/interfaces/IHub.sol
/// (and IHubBase.sol, which IHub extends)
/// Modifications:
/// - Trimmed to the read-only surface needed for rate/liquidity display and share<->asset
///   conversion. No mutating Hub functions (add/remove/draw/restore/sweep/reclaim/etc) are called
///   directly by this money market -- all fund movement goes through ISpoke.
interface IHubBase {
    struct SpokeData {
        uint120 drawnShares;
        uint120 premiumShares;
        int200 premiumOffsetRay;
        uint120 addedShares;
        uint40 addCap;
        uint40 drawCap;
        uint24 riskPremiumThreshold;
        bool active;
        bool halted;
        uint200 deficitRay;
    }

    struct Asset {
        uint120 liquidity;
        uint120 realizedFees;
        uint8 decimals;
        uint120 addedShares;
        uint120 swept;
        int200 premiumOffsetRay;
        uint120 drawnShares;
        uint120 premiumShares;
        uint16 liquidityFee;
        uint120 drawnIndex;
        uint96 drawnRate;
        uint40 lastUpdateTimestamp;
        address underlying;
        address irStrategy;
        address reinvestmentController;
        address feeReceiver;
        uint200 deficitRay;
    }

    /// @notice Current annualized borrow rate for `assetId`, RAY-scaled (1e27) -- same convention
    /// as Aave V3's `currentVariableBorrowRate`. There is no supply-rate equivalent; V4 exposes
    /// only this one rate primitive.
    function getAssetDrawnRate(uint256 assetId) external view returns (uint256);

    function getAsset(uint256 assetId) external view returns (Asset memory);

    /// @notice Per-(asset, spoke) caps and current usage. `addCap`/`drawCap` are expressed in
    /// whole assets (not scaled by decimals); `type(uint40).max` means uncapped.
    function getSpoke(uint256 assetId, address spoke) external view returns (SpokeData memory);

    function previewRemoveByShares(uint256 assetId, uint256 shares) external view returns (uint256);
    function previewRestoreByShares(uint256 assetId, uint256 shares) external view returns (uint256);

    /// @notice The asset-level total value backing all `addedShares` (liquidity + swept + owed -
    /// fees), already aggregated Hub-side.
    /// https://github.com/aave/aave-v4/blob/2524fe4018a42750300e114f2a8c4355df62a878/src/hub/Hub.sol#L513-L515
    /// https://github.com/aave/aave-v4/blob/2524fe4018a42750300e114f2a8c4355df62a878/src/hub/libraries/AssetLogic.sol#L79-L96
    function getAddedAssets(uint256 assetId) external view returns (uint256);

    /// @notice Total amount of `assetId` owed to the Hub by `spoke` (drawn + premium debt,
    /// computed internally -- handles the signed premium-offset subtraction itself, so callers
    /// never need to touch `SpokeData.premiumOffsetRay`'s sign).
    function getSpokeTotalOwed(uint256 assetId, address spoke) external view returns (uint256);

    /// @notice Total amount of `assetId` owed to the Hub across all spokes (drawn + premium debt,
    /// Hub-wide) -- the asset-level equivalent of `getSpokeTotalOwed`.
    function getAssetTotalOwed(uint256 assetId) external view returns (uint256);
}
