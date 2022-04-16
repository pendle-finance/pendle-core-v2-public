// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./FixedPoint.sol";
import "./LogExpMath.sol";
import "../SCYIndex.sol";

struct MarketAllParams {
    int256 totalOt;
    int256 totalScy;
    int256 totalLp;
    uint256 oracleRate;
    /// immutable variables ///
    int256 scalarRoot;
    uint256 feeRateRoot;
    uint256 rateOracleTimeWindow;
    uint256 expiry;
    int256 reserveFeePercent; // base 100
    /// last trade data ///
    uint256 lastImpliedRate;
    uint256 lastTradeTime;
}

// params that are expensive to compute, therefore we pre-compute them
struct MarketPreCompute {
    int256 rateScalar;
    int256 totalAsset;
    int256 rateAnchor;
    int256 feeRate;
}

struct MarketStorage {
    int128 totalOt;
    int128 totalScy;
    uint112 lastImpliedRate;
    uint112 oracleRate;
    uint32 lastTradeTime;
}

// solhint-disable ordering
library MarketMathCore {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;

    int256 internal constant MINIMUM_LIQUIDITY = 10**3;
    int256 internal constant PERCENTAGE_DECIMALS = 100;
    uint256 internal constant DAY = 86400;
    uint256 internal constant IMPLIED_RATE_TIME = 360 * DAY;

    int256 internal constant MAX_MARKET_PROPORTION = (1e18 * 96) / 100;

    function addLiquidityCore(
        MarketAllParams memory market,
        SCYIndex index,
        int256 scyDesired,
        int256 otDesired
    )
        internal
        pure
        returns (
            int256 lpToReserve,
            int256 lpToAccount,
            int256 scyUsed,
            int256 otUsed
        )
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(scyDesired > 0 && otDesired > 0, "ZERO_AMOUNTS");

        /// ------------------------------------------------------------
        /// MATH
        /// ------------------------------------------------------------
        if (market.totalLp == 0) {
            lpToAccount = index.scyToAsset(scyDesired).subNoNeg(MINIMUM_LIQUIDITY);
            lpToReserve = MINIMUM_LIQUIDITY;
            scyUsed = scyDesired;
            otUsed = otDesired;
        } else {
            int256 netLpByOt = (otDesired * market.totalLp) / market.totalOt;
            int256 netLpByScy = (scyDesired * market.totalLp) / market.totalScy;
            if (netLpByOt < netLpByScy) {
                lpToAccount = netLpByOt;
                otUsed = otDesired;
                scyUsed = (market.totalScy * lpToAccount) / market.totalLp;
            } else {
                lpToAccount = netLpByScy;
                scyUsed = scyDesired;
                otUsed = (market.totalOt * lpToAccount) / market.totalLp;
            }
        }

        require(lpToAccount > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        /// ------------------------------------------------------------
        /// WRITE
        /// ------------------------------------------------------------
        market.totalScy += scyUsed;
        market.totalOt += otUsed;
        market.totalLp += lpToAccount + lpToReserve;
    }

    function removeLiquidityCore(MarketAllParams memory market, int256 lpToRemove)
        internal
        pure
        returns (int256 scyToAccount, int256 netOtToAccount)
    {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(lpToRemove > 0, "invalid lp amount");

        /// ------------------------------------------------------------
        /// MATH
        /// ------------------------------------------------------------
        scyToAccount = (lpToRemove * market.totalScy) / market.totalLp;
        netOtToAccount = (lpToRemove * market.totalOt) / market.totalLp;

        /// ------------------------------------------------------------
        /// WRITE
        /// ------------------------------------------------------------
        market.totalLp = market.totalLp.subNoNeg(lpToRemove);
        market.totalOt = market.totalOt.subNoNeg(netOtToAccount);
        market.totalScy = market.totalScy.subNoNeg(scyToAccount);
    }

    function executeTradeCore(
        MarketAllParams memory market,
        SCYIndex index,
        int256 netOtToAccount,
        uint256 blockTime
    ) internal pure returns (int256 netScyToAccount, int256 netScyToReserve) {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(blockTime < market.expiry, "market expired");
        require(market.totalOt > netOtToAccount, "insufficient liquidity");

        /// ------------------------------------------------------------
        /// MATH
        /// ------------------------------------------------------------
        MarketPreCompute memory comp = getMarketPreCompute(market, index, blockTime);

        (int256 netAssetToAccount, int256 netAssetToReserve) = calcTrade(
            market,
            comp,
            netOtToAccount
        );

        netScyToAccount = index.assetToScy(netAssetToAccount);
        netScyToReserve = index.assetToScy(netAssetToReserve);

        /// ------------------------------------------------------------
        /// WRITE
        /// ------------------------------------------------------------
        _setNewMarketStateTrade(market, comp, index, netOtToAccount, netScyToAccount, blockTime);
    }

    function getMarketPreCompute(
        MarketAllParams memory market,
        SCYIndex index,
        uint256 blockTime
    ) internal pure returns (MarketPreCompute memory res) {
        require(blockTime < market.expiry, "market expired");

        uint256 timeToExpiry = market.expiry - blockTime;

        res.rateScalar = _getRateScalar(market, timeToExpiry);
        res.totalAsset = index.scyToAsset(market.totalScy);

        require(market.totalOt != 0 && res.totalAsset != 0, "invalid market state");

        res.rateAnchor = _getRateAnchor(
            market.totalOt,
            market.lastImpliedRate,
            res.totalAsset,
            res.rateScalar,
            timeToExpiry
        );
        res.feeRate = _getExchangeRateFromImpliedRate(market.feeRateRoot, timeToExpiry);
    }

    function calcTrade(
        MarketAllParams memory market,
        MarketPreCompute memory comp,
        int256 netOtToAccount
    ) internal pure returns (int256 netAssetToAccount, int256 netAssetToReserve) {
        int256 preFeeExchangeRate = _getExchangeRate(
            market.totalOt,
            comp.totalAsset,
            comp.rateScalar,
            comp.rateAnchor,
            netOtToAccount
        );

        int256 preFeeAssetToAccount = netOtToAccount.divDown(preFeeExchangeRate).neg();
        int256 fee = comp.feeRate;

        if (netOtToAccount > 0) {
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(fee);
            require(postFeeExchangeRate >= FixedPoint.IONE, "exchange rate below 1");
            fee = preFeeAssetToAccount.mulDown(FixedPoint.IONE - fee);
        } else {
            fee = ((preFeeAssetToAccount * (FixedPoint.IONE - fee)) / fee).neg();
        }

        netAssetToReserve = (fee * market.reserveFeePercent) / PERCENTAGE_DECIMALS;
        netAssetToAccount = preFeeAssetToAccount - fee;
        // netAssetToMarket = (preFeeAssetToAccount - fee + netAssetToReserve)
        //     .neg();
    }

    function _setNewMarketStateTrade(
        MarketAllParams memory market,
        MarketPreCompute memory comp,
        SCYIndex index,
        int256 netOtToAccount,
        int256 netScyToAccount,
        uint256 blockTime
    ) internal pure {
        uint256 timeToExpiry = market.expiry - blockTime;

        market.lastTradeTime = blockTime;

        market.totalOt = market.totalOt.subNoNeg(netOtToAccount);
        market.totalScy = market.totalScy.subNoNeg(netScyToAccount);

        market.lastImpliedRate = _getImpliedRate(
            market.totalOt,
            index.scyToAsset(market.totalScy),
            comp.rateScalar,
            comp.rateAnchor,
            timeToExpiry
        );
        require(market.lastImpliedRate != 0, "zero impliedRate");
    }

    function _getRateAnchor(
        int256 totalOt,
        uint256 lastImpliedRate,
        int256 totalAsset,
        int256 rateScalar,
        uint256 timeToExpiry
    ) internal pure returns (int256 rateAnchor) {
        // This is the exchange rate at the new time to expiry
        int256 newExchangeRate = _getExchangeRateFromImpliedRate(lastImpliedRate, timeToExpiry);

        require(newExchangeRate >= FixedPoint.IONE, "exchange rate below 1");

        {
            // totalOt / (totalOt + totalAsset)
            int256 proportion = totalOt.divDown(totalOt + totalAsset);

            int256 lnProportion = _logProportion(proportion);

            // newExchangeRate - ln(proportion / (1 - proportion)) / rateScalar
            rateAnchor = newExchangeRate - lnProportion.divDown(rateScalar);
        }
    }

    /// @notice Calculates the current market implied rate.
    /// @return impliedRate the implied rate
    function _getImpliedRate(
        int256 totalOt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        uint256 timeToExpiry
    ) internal pure returns (uint256 impliedRate) {
        // This will check for exchange rates < FixedPoint.IONE
        int256 exchangeRate = _getExchangeRate(totalOt, totalAsset, rateScalar, rateAnchor, 0);

        // exchangeRate >= 1 so its ln >= 0
        uint256 lnRate = exchangeRate.ln().Uint();

        impliedRate = (lnRate * IMPLIED_RATE_TIME) / timeToExpiry;
    }

    /// @notice Converts an implied rate to an exchange rate given a time to expiry. The
    /// formula is E = e^rt
    function _getExchangeRateFromImpliedRate(uint256 impliedRate, uint256 timeToExpiry)
        internal
        pure
        returns (int256 exchangeRate)
    {
        uint256 rt = (impliedRate * timeToExpiry) / IMPLIED_RATE_TIME;

        exchangeRate = LogExpMath.exp(rt.Int());
    }

    /// @notice Returns the exchange rate between OT and Asset for the given market
    /// Calculates the following exchange rate:
    ///     (1 / rateScalar) * ln(proportion / (1 - proportion)) + rateAnchor
    /// where:
    ///     proportion = totalOt / (totalOt + totalUnderlyingAsset)
    function _getExchangeRate(
        int256 totalOt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        int256 netOtToAccount
    ) internal pure returns (int256 exchangeRate) {
        int256 numerator = totalOt.subNoNeg(netOtToAccount);

        // This is the proportion scaled by FixedPoint.IONE
        // (totalOt - netOtToAccount) / (totalOt + totalAsset)
        int256 proportion = (numerator.divDown(totalOt + totalAsset));

        // This limit is here to prevent the market from reaching extremely high interest rates via an
        // excessively large proportion (high amounts of OT relative to Asset).
        // Market proportion can only increase via swapping OT to SCY (OT is added to the market and SCY is
        // removed). Over time, the yield from SCY will slightly decrease the proportion (the
        // amount of Asset in the market must be monotonically increasing). Therefore it is not
        // possible for the proportion to go over max market proportion unless borrowing occurs.
        require(proportion <= MAX_MARKET_PROPORTION, "max proportion exceeded");

        int256 lnProportion = _logProportion(proportion);

        // lnProportion / rateScalar + rateAnchor
        exchangeRate = lnProportion.divDown(rateScalar) + rateAnchor;

        // Do not succeed if interest rates fall below 1
        require(exchangeRate >= FixedPoint.IONE, "exchange rate below 1");
    }

    function _logProportion(int256 proportion) internal pure returns (int256 res) {
        // This will result in divide by zero, short circuit
        require(proportion != FixedPoint.IONE, "proportion must not be one");

        // Convert proportion to what is used inside the logit function (p / (1-p))
        int256 logitP = proportion.divDown(FixedPoint.IONE - proportion);

        res = logitP.ln();
    }

    function _getRateScalar(MarketAllParams memory market, uint256 timeToExpiry)
        internal
        pure
        returns (int256 rateScalar)
    {
        rateScalar = (market.scalarRoot * IMPLIED_RATE_TIME.Int()) / timeToExpiry.Int();
        require(rateScalar > 0, "rateScalar underflow");
    }

    function setInitialImpliedRate(
        MarketAllParams memory market,
        SCYIndex index,
        int256 initialAnchor,
        uint256 blockTime
    ) internal pure {
        /// ------------------------------------------------------------
        /// CHECKS
        /// ------------------------------------------------------------
        require(blockTime < market.expiry, "market expired");

        /// ------------------------------------------------------------
        /// MATH
        /// ------------------------------------------------------------
        int256 totalAsset = index.scyToAsset(market.totalScy);
        uint256 timeToExpiry = market.expiry - blockTime;
        int256 rateScalar = _getRateScalar(market, timeToExpiry);

        /// ------------------------------------------------------------
        /// WRITE
        /// ------------------------------------------------------------
        market.lastImpliedRate = _getImpliedRate(
            market.totalOt,
            totalAsset,
            rateScalar,
            initialAnchor,
            market.expiry - blockTime
        );
    }

    function updateNewRateOracle(MarketAllParams memory market, uint256 blockTime)
        internal
        pure
        returns (uint256)
    {
        // This can occur when using a view function get to a market state in the past
        if (market.lastTradeTime > blockTime) {
            market.oracleRate = market.lastImpliedRate;
            return market.oracleRate;
        }

        uint256 timeDiff = blockTime - market.lastTradeTime;
        if (timeDiff > market.rateOracleTimeWindow) {
            // If past the time window just return the market.lastImpliedRate
            market.oracleRate = market.lastImpliedRate;
            return market.oracleRate;
        }

        // (currentTs - previousTs) / timeWindow
        uint256 lastTradeWeight = timeDiff.divDown(market.rateOracleTimeWindow);

        // 1 - (currentTs - previousTs) / timeWindow
        uint256 oracleWeight = FixedPoint.ONE - lastTradeWeight;

        uint256 newOracleRate = market.lastTradeTime.mulDown(lastTradeWeight) +
            market.oracleRate.mulDown(oracleWeight);

        market.oracleRate = newOracleRate;
        return market.oracleRate;
    }
}
