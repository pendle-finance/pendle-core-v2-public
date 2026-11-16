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

    /// @notice Aave V4 has one `collateralFactor` for both, so `ltv` is the liquidation line (HF == 1), not a
    /// safe target. The caller's `postBorrowMaxLTV` must give the whole safety margin.
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

    /// @notice Known limitation: `borrowing` includes Hub cash and the spoke's `drawCap`, but not the spoke-wide
    /// premium limit of `Hub._applyPremiumDelta`. A borrow within `borrowing` can still revert when the spoke is
    /// at that limit and the box's collateral has a high `collateralRisk`.
    function _liquidity(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        (ISpoke spoke, uint256 collateralReserveId, uint256 debtReserveId) = AaveV4MMPayloadLib.unwrap(bd.mmPayload);

        // Lending
        {
            ISpoke.Reserve memory collReserve = spoke.getReserve(collateralReserveId);
            IHubBase.SpokeData memory sd = collReserve.hub.getSpoke(collReserve.assetId, address(spoke));
            if (sd.addCap == type(uint40).max) {
                lending = IERC20(collReserve.underlying).totalSupply(); // No supply cap
            } else {
                uint256 capAssets = uint256(sd.addCap) * 10 ** collReserve.decimals;
                uint256 currentAssets = collReserve.hub.previewRemoveByShares(collReserve.assetId, sd.addedShares);
                lending = capAssets.subMax0(currentAssets);
            }
        }

        // Borrowing
        {
            ISpoke.Reserve memory reserve = spoke.getReserve(debtReserveId);
            IHubBase hub = reserve.hub;
            IHubBase.SpokeData memory sd = hub.getSpoke(reserve.assetId, address(spoke));
            uint256 hubLiquidity = hub.getAsset(reserve.assetId).liquidity;
            if (sd.drawCap == type(uint40).max) {
                borrowing = hubLiquidity;
            } else {
                uint256 capAssets = uint256(sd.drawCap) * 10 ** reserve.decimals;

                // owed = drawnShares * drawnIndex + premium + deficit; `getSpokeTotalOwed` is all but the deficit.
                // https://github.com/aave/aave-v4/blob/2524fe4018a42750300e114f2a8c4355df62a878/src/hub/libraries/AssetLogic.sol#L229
                uint256 owedAssets = hub.getSpokeTotalOwed(reserve.assetId, address(spoke)) + _trimRay(sd.deficitRay);
                uint256 capHeadroom = capAssets.subMax0(owedAssets);
                borrowing = PMath.min(hubLiquidity, capHeadroom);
            }
        }
    }

    /// @dev `borrowing` is for this box: it includes the box's risk premium (`getUserLastRiskPremium`).
    /// `lending` is market-wide: it includes the premium of all borrowers. See `_lendingApy`.
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

    /// @dev APY of `drawnRate * interestBearing / totalValue * (1 - liquidityFee)`.
    function _lendingApy(ISpoke.Reserve memory reserve) internal view returns (uint256) {
        // `totalValue` is the suppliers' whole claim, read directly (no shares rounding):
        // https://github.com/aave/aave-v4/blob/2524fe4018a42750300e114f2a8c4355df62a878/src/hub/libraries/AssetLogic.sol#L79-L96

        IHubBase.Asset memory collAsset = reserve.hub.getAsset(reserve.assetId);
        uint256 totalValue = reserve.hub.getAddedAssets(reserve.assetId);

        if (totalValue == 0) return 0;

        // The principal that `drawnRate` accrues on: (drawnShares + premiumShares) * drawnIndex.
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

    // ========== Internal helpers ==========

    /// @dev Compounds daily, like every other money market, so the APYs compare. Aave V4 compounds on each Hub
    /// interaction, so this differs from Aave's own figure (about 0.01pp at normal rates).
    function _aaveV4Apy(uint256 rate) internal pure returns (uint256) {
        return _apy({rate: rate, perSeconds: 365 days});
    }

    function _bpsToWad(uint256 bps) internal pure returns (uint256) {
        return bps * 1e14;
    }

    function _rayToWad(uint256 ray) internal pure returns (uint256) {
        return ray / 1e9;
    }

    /// @dev RAY to a plain integer.
    function _trimRay(uint256 ray) internal pure returns (uint256) {
        return ray / 1e27;
    }
}
