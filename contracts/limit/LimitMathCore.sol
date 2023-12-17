// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IPLimitRouter.sol";
import "../core/Market/MarketMathCore.sol";
import "../interfaces/IPMarketFactory.sol";

library LimitMathCore {
    using PYIndexLib for PYIndex;
    using PYIndexLib for IPYieldToken;
    using PMath for uint256;
    using PMath for int256;

    function calcBatch(
        FillOrderParams[] memory params,
        address YT,
        uint256 lnFeeRateRoot
    ) internal returns (IPLimitOrderType.FillResults memory out) {
        return
            calcBatch(
                params,
                IPYieldToken(YT).expiry() - block.timestamp,
                IPYieldToken(YT).pyIndexCurrent(),
                lnFeeRateRoot
            );
    }

    // --- PURE FUNCTIONS ---
    function calcBatch(
        FillOrderParams[] memory params,
        uint256 timeToExpiry,
        uint256 pyIndex,
        uint256 lnFeeRateRoot
    ) internal pure returns (IPLimitOrderType.FillResults memory out) {
        uint256 len = params.length;
        out.netMakings = new uint256[](len);
        out.netTakings = new uint256[](len);
        out.netFees = new uint256[](len);
        out.notionalVolumes = new uint256[](len);

        function(uint256, uint256, PYIndex, uint256)
            internal
            pure
            returns (uint256, uint256, uint256) calc = getCalcFunctions(params[0].order.orderType);

        uint256 feeRate = impliedRateToExchangeRate(lnFeeRateRoot, timeToExpiry);

        for (uint256 i = 0; i < len; i++) {
            FillOrderParams memory param = params[i];
            if (param.makingAmount == 0) continue; // nothing changes

            uint256 exchangeRate = impliedRateToExchangeRate(param.order.lnImpliedRate, timeToExpiry);

            out.netMakings[i] = param.makingAmount;
            (out.netTakings[i], out.netFees[i], out.notionalVolumes[i]) = calc(
                out.netMakings[i],
                exchangeRate,
                PYIndex.wrap(pyIndex),
                feeRate
            );

            require(out.netTakings[i] > 0, "LOP: can't swap 0 amount");

            out.totalMaking += out.netMakings[i];
            out.totalTaking += out.netTakings[i];
            out.totalFee += out.netFees[i];
            out.totalNotionalVolume += out.notionalVolumes[i];
        }
    }

    function calcSyForPt(
        uint256 makeSy,
        uint256 r,
        PYIndex index,
        uint256 f
    ) internal pure returns (uint256 takePt, uint256 fee, uint256 notionalVolume) {
        // takePt = makeSy * index * r
        // fee = makeSy * (f - 1) / f
        // notionalVolume = makeSy

        takePt = index.syToAsset(makeSy).mulDown(r);
        fee = (makeSy * (f - PMath.ONE)) / f;
        notionalVolume = makeSy;
    }

    function calcPtForSy(
        uint256 makePt,
        uint256 r,
        PYIndex index,
        uint256 f
    ) internal pure returns (uint256 takeSy, uint256 fee, uint256 notionalVolume) {
        // takeAsset = make / r
        // takeSy = takeAsset / index
        // fee = takeSy * (f-1)
        // notionalVolume = takeSy

        takeSy = index.assetToSy(makePt.divDown(r));
        fee = takeSy.mulDown(f - PMath.ONE);
        notionalVolume = takeSy;
    }

    function calcSyForYt(
        uint256 makeSy,
        uint256 r,
        PYIndex index,
        uint256 f
    ) internal pure returns (uint256 takeYt, uint256 fee, uint256 notionalVolume) {
        // pt = makeSy * index * r
        // yt = pt / (r-1)
        // fee = makeSy * (f-1) / (r-1)
        // notionalVolume = makeSy / (r-1)
        uint256 pt_yt_ratio = r - PMath.ONE;

        takeYt = (index.syToAsset(makeSy) * r) / pt_yt_ratio;
        fee = (makeSy * (f - PMath.ONE)) / pt_yt_ratio;
        notionalVolume = makeSy.divDown(pt_yt_ratio);
    }

    function calcYtForSy(
        uint256 makeYt,
        uint256 r,
        PYIndex index,
        uint256 f
    ) internal pure returns (uint256 takeSy, uint256 fee, uint256 notionalVolume) {
        // pt = yt * (r-1)
        // takeSy = pt / r / index
        // feeSy = takeSy * (f-1) / f / (r-1)
        // notionalVolume = takeSy / (r-1)
        uint256 pt_yt_ratio = r - PMath.ONE;

        takeSy = index.assetToSy((makeYt * pt_yt_ratio) / r);
        fee = ((takeSy * (f - PMath.ONE)) / f).divDown(pt_yt_ratio);
        notionalVolume = takeSy.divDown(pt_yt_ratio);
    }

    function impliedRateToExchangeRate(uint256 lnRate, uint256 timeToExpiry) internal pure returns (uint256) {
        return MarketMathCore._getExchangeRateFromImpliedRate(lnRate, timeToExpiry).Uint();
    }

    function getCalcFunctions(
        IPLimitOrderType.OrderType t
    )
        internal
        pure
        returns (function(uint256, uint256, PYIndex, uint256) internal pure returns (uint256, uint256, uint256) calc)
    {
        if (t == IPLimitOrderType.OrderType.SY_FOR_PT) {
            return (calcSyForPt);
        } else if (t == IPLimitOrderType.OrderType.PT_FOR_SY) {
            return (calcPtForSy);
        } else if (t == IPLimitOrderType.OrderType.SY_FOR_YT) {
            return (calcSyForYt);
        } else {
            return (calcYtForSy);
        }
    }
}
