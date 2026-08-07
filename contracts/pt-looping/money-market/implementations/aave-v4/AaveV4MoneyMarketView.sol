//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISpoke} from "./dependencies/ISpoke.sol";
import {IHubBase} from "./dependencies/IHubBase.sol";
import {AaveV4MMPayloadLib} from "./AaveV4MMPayloadLib.sol";

import {BaseMoneyMarketView} from "../../BaseMoneyMarketView.sol";
import {IPLoopPositionBox, BoxData} from "../../../../interfaces/IPLoopPositionBox.sol";
import {PMath} from "../../../../core/libraries/math/PMath.sol";

contract AaveV4MoneyMarketView is BaseMoneyMarketView {
    using PMath for uint256;

    constructor(string memory _moneyMarketName, address _ptLooper) BaseMoneyMarketView(_moneyMarketName, _ptLooper) {}

    /// @notice Aave V4 has no separate borrow-LTV / liquidation-threshold pair — `DynamicReserveConfig`
    /// carries a single `collateralFactor` that serves both roles, so both return values are equal.
    /// Callers MUST NOT treat `ltv` as a safe borrowing target the way they can on the V3 adapter:
    /// borrowing to `ltv` here means borrowing to exactly `HF == 1`, i.e. to the liquidation line.
    /// The entire safety margin must be supplied by the caller's own `postBorrowMaxLTV` haircut.
    function _thresholds(IPLoopPositionBox box, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 ltv, uint256 liquidationThreshold)
    {
        (ISpoke spoke, uint256 collateralReserveId,) = AaveV4MMPayloadLib.unwrap(bd.mmPayload);
        uint32 dynamicConfigKey = spoke.getUserPosition(collateralReserveId, box.SPOKE_MONEY_MARKET()).dynamicConfigKey;
        ISpoke.DynamicReserveConfig memory dc = spoke.getDynamicReserveConfig(collateralReserveId, dynamicConfigKey);

        ltv = liquidationThreshold = _bpsToWad(dc.collateralFactor);
    }

    /// @notice Known limitations:
    /// The returned `borrowing` accounts for Hub cash and the per-spoke `drawCap`, but not for
    /// `Hub._applyPremiumDelta`'s aggregate constraint
    /// `spoke.premiumShares <= spoke.drawnShares.percentMulUp(riskPremiumThreshold)`.
    /// That threshold is a spoke-wide quantity driven by all borrowers on the spoke, so it cannot
    /// be meaningfully attributed to a single box and any computed value would be immediately
    /// stale. A borrow within the returned figure may still revert if the spoke is at its
    /// premium threshold and this box's collateral carries a high `collateralRisk`.
    function _liquidity(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        (ISpoke spoke, uint256 collateralReserveId, uint256 debtReserveId) = AaveV4MMPayloadLib.unwrap(bd.mmPayload);

        // lending
        {
            ISpoke.Reserve memory collReserve = spoke.getReserve(collateralReserveId);
            IHubBase.SpokeData memory sd = collReserve.hub.getSpoke(collReserve.assetId, address(spoke));
            if (sd.addCap == type(uint40).max) {
                lending = IERC20(collReserve.underlying).totalSupply(); // Infinite supply cap
            } else {
                uint256 capAssets = uint256(sd.addCap) * 10 ** collReserve.decimals;
                uint256 currentAssets = collReserve.hub.previewRemoveByShares(collReserve.assetId, sd.addedShares);
                lending = capAssets.subMax0(currentAssets);
            }
        }

        // borrowing
        {
            ISpoke.Reserve memory reserve = spoke.getReserve(debtReserveId);
            IHubBase hub = reserve.hub;
            IHubBase.SpokeData memory sd = hub.getSpoke(reserve.assetId, address(spoke));
            uint256 hubLiquidity = hub.getAsset(reserve.assetId).liquidity;
            if (sd.drawCap == type(uint40).max) {
                borrowing = hubLiquidity;
            } else {
                uint256 capAssets = uint256(sd.drawCap) * 10 ** reserve.decimals;

                // * `_calculateAggregatedOwedRay`: https://github.com/aave/aave-v4/blob/2524fe4018a42750300e114f2a8c4355df62a878/src/hub/libraries/AssetLogic.sol#L229
                //      owedAssets = (drawnShares * drawnIndex) + premiumRay + deficitRay
                // Besides `deficitRay`, the rest is `hub.getSpokeTotalOwed`
                uint256 owedAssets = hub.getSpokeTotalOwed(reserve.assetId, address(spoke)) + _trimRay(sd.deficitRay);
                uint256 capHeadroom = capAssets.subMax0(owedAssets);
                borrowing = PMath.min(hubLiquidity, capHeadroom);
            }
        }
    }

    /// @dev `borrowing` (`_borrowApy`) is position-specific -- includes this box's own risk
    /// premium (`getUserLastRiskPremium`), a per-position surcharge, not a market-wide figure:
    /// https://github.com/aave/aave-v4/blob/2524fe4018a42750300e114f2a8c4355df62a878/src/spoke/interfaces/ISpoke.sol#L750
    /// `lending` (`_lendingApy`) is market-wide -- no single position's premium applies, so it
    /// folds in premium's *aggregate* contribution via the market's drawn+premium shares instead.
    /// See `_lendingApy`.
    function _rates(IPLoopPositionBox box, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        (ISpoke spoke, uint256 collateralReserveId, uint256 debtReserveId) = AaveV4MMPayloadLib.unwrap(bd.mmPayload);

        uint256 boxRiskPremiumBps = spoke.getUserLastRiskPremium(box.SPOKE_MONEY_MARKET());
        borrowing = _borrowApyWithPremium(spoke.getReserve(debtReserveId), boxRiskPremiumBps);
        lending = _lendingApy(spoke.getReserve(collateralReserveId));
    }

    function _borrowApyWithPremium(ISpoke.Reserve memory reserve, uint256 riskPremiumBps)
        internal
        view
        returns (uint256)
    {
        return _aaveV4Apy(_drawnRateWad(reserve).tweakUp(_bpsToWad(riskPremiumBps)));
    }

    /// @return lendingApy = _apy(drawnRate * usageRatio * (1 - liquidityFee), perSeconds: 365 days)
    /// - usageRatio (or utilization): `interestBearing / totalValue`
    function _lendingApy(ISpoke.Reserve memory reserve) internal view returns (uint256) {
        // * `totalValue` - the real supplier claim base
        //      totalAddedAssets = liquidity + swept + (drawn+premium+deficit) - realizedFees - unrealizedFees
        // which is exactly `Hub.getAddedAssets(assetId)` (returns `_assets[assetId].totalAddedAssets()`
        // directly -- not a shares<->assets conversion, so unlike `previewRemoveByShares` there's no
        // `SharesMath` virtual-offset rounding)
        // - https://github.com/aave/aave-v4/blob/2524fe4018a42750300e114f2a8c4355df62a878/src/hub/libraries/AssetLogic.sol#L79-L96

        IHubBase.Asset memory collAsset = reserve.hub.getAsset(reserve.assetId);
        uint256 totalValue = reserve.hub.getAddedAssets(reserve.assetId);

        if (totalValue == 0) return 0;

        // `interestBearing` must be the principal that `drawnRate` compounds
        // against going forward, with no offset subtracted
        //      interestBearing = (drawnShares + premiumShares) * drawnIndex,
        uint256 interestBearingShares = uint256(collAsset.drawnShares) + collAsset.premiumShares;
        uint256 interestBearing = reserve.hub.previewRestoreByShares(reserve.assetId, interestBearingShares);

        uint256 drawnRate = _drawnRateWad(reserve);
        uint256 usageRatio = interestBearing.divDown(totalValue);
        uint256 supplyApr = drawnRate.mulDown(usageRatio).tweakDown(_bpsToWad(collAsset.liquidityFee));
        return _aaveV4Apy(supplyApr);
    }

    function _drawnRateWad(ISpoke.Reserve memory reserve) internal view returns (uint256) {
        return _rayToWad(reserve.hub.getAssetDrawnRate(reserve.assetId));
    }

    /// === Internal helpers ===

    /// @dev BaseMoneyMarketView._apy is still used here, by convention, to compound
    /// daily, uniformly across all money markets so their APYs stay mutually
    /// comparable.
    ///
    /// For Aave V4 in particular, `AssetLogic.accrue` applies linear
    /// interest per interval and multiplies the index on every Hub interaction,
    /// so the true compounding frequency equals the asset's interaction
    /// frequency: this figure understates for busy assets and overstates for
    /// quiet ones, and is not expected to match Aave's own frontend exactly.
    ///
    /// The divergence is ~0.01pp at ordinary rates and only becomes material at
    /// very high ones.
    function _aaveV4Apy(uint256 rate) internal pure returns (uint256) {
        return _apy({rate: rate, perSeconds: 365 days});
    }

    // BPS (1e4) -> WAD (1e18)
    function _bpsToWad(uint256 bps) internal pure returns (uint256) {
        return bps * 1e14;
    }

    // RAY (1e27) -> WAD (1e18)
    function _rayToWad(uint256 ray) internal pure returns (uint256) {
        return ray / 1e9;
    }

    // RAY (1e27) -> no decimals (1e0)
    function _trimRay(uint256 ray) internal pure returns (uint256) {
        return ray / 1e27;
    }
}
