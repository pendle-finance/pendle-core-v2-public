// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./Math.sol";
import "./LogExpMath.sol";
import "../SCYIndex.sol";

struct MarketState {
    int256 totalOt;
    int256 totalScy;
    int256 totalLp;
    uint256 oracleRate;
    address treasury;
    /// immutable variables ///
    int256 scalarRoot;
    uint256 lnFeeRateRoot;
    uint256 rateOracleTimeWindow;
    uint256 expiry;
    uint256 reserveFeePercent; // base 100
    /// last trade data ///
    uint256 lastLnImpliedRate;
    uint256 lastTradeTime;
}

// params that are expensive to compute, therefore we pre-compute them
struct MarketPreCompute {
    int256 rateScalar;
    int256 totalAsset;
    int256 rateAnchor;
    int256 lnFeeRate;
}

struct MarketStorage {
    int128 totalOt;
    int128 totalScy;
    uint112 lastLnImpliedRate;
    uint112 oracleRate;
    uint32 lastTradeTime;
}

// solhint-disable ordering
library MarketMathCore {
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;

    int256 internal constant MINIMUM_LIQUIDITY = 10**3;
    int256 internal constant PERCENTAGE_DECIMALS = 100;
    uint256 internal constant DAY = 86400;
    uint256 internal constant IMPLIED_RATE_TIME = 360 * DAY;

    int256 internal constant MAX_MARKET_PROPORTION = (1e18 * 96) / 100;

    function addLiquidityCore(
        MarketState memory market,
        SCYIndex index,
        int256 scyDesired,
        int256 otDesired,
        bool updateState
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
        if (updateState) {
            market.totalScy += scyUsed;
            market.totalOt += otUsed;
            market.totalLp += lpToAccount + lpToReserve;
        }
    }

    function removeLiquidityCore(
        MarketState memory market,
        int256 lpToRemove,
        bool updateState
    ) internal pure returns (int256 scyToAccount, int256 netOtToAccount) {
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
        if (updateState) {
            market.totalLp = market.totalLp.subNoNeg(lpToRemove);
            market.totalOt = market.totalOt.subNoNeg(netOtToAccount);
            market.totalScy = market.totalScy.subNoNeg(scyToAccount);
        }
    }

    function executeTradeCore(
        MarketState memory market,
        SCYIndex index,
        int256 netOtToAccount,
        uint256 blockTime,
        bool updateState
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
        if (updateState) {
            _setNewMarketStateTrade(
                market,
                comp,
                index,
                netOtToAccount,
                netScyToAccount,
                blockTime
            );
        }
    }

    function getMarketPreCompute(
        MarketState memory market,
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
            market.lastLnImpliedRate,
            res.totalAsset,
            res.rateScalar,
            timeToExpiry
        );
        res.lnFeeRate = _getExchangeRateFromImpliedRate(market.lnFeeRateRoot, timeToExpiry);
    }

    function calcTrade(
        MarketState memory market,
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
        int256 fee = comp.lnFeeRate;

        if (netOtToAccount > 0) {
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(fee);
            require(postFeeExchangeRate >= Math.IONE, "exchange rate below 1");
            fee = preFeeAssetToAccount.mulDown(Math.IONE - fee);
        } else {
            fee = ((preFeeAssetToAccount * (Math.IONE - fee)) / fee).neg();
        }

        netAssetToReserve = (fee * market.reserveFeePercent.Int()) / PERCENTAGE_DECIMALS;
        netAssetToAccount = preFeeAssetToAccount - fee;
        // netAssetToMarket = (preFeeAssetToAccount - fee + netAssetToReserve)
        //     .neg();
    }

    function _setNewMarketStateTrade(
        MarketState memory market,
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

        market.lastLnImpliedRate = _getLnImpliedRate(
            market.totalOt,
            index.scyToAsset(market.totalScy),
            comp.rateScalar,
            comp.rateAnchor,
            timeToExpiry
        );
        require(market.lastLnImpliedRate != 0, "zero lnImpliedRate");
    }

    function _getRateAnchor(
        int256 totalOt,
        uint256 lastLnImpliedRate,
        int256 totalAsset,
        int256 rateScalar,
        uint256 timeToExpiry
    ) internal pure returns (int256 rateAnchor) {
        int256 newExchangeRate = _getExchangeRateFromImpliedRate(lastLnImpliedRate, timeToExpiry);

        require(newExchangeRate >= Math.IONE, "exchange rate below 1");

        {
            int256 proportion = totalOt.divDown(totalOt + totalAsset);

            int256 lnProportion = _logProportion(proportion);

            rateAnchor = newExchangeRate - lnProportion.divDown(rateScalar);
        }
    }

    /// @notice Calculates the current market implied rate.
    /// @return lnImpliedRate the implied rate
    function _getLnImpliedRate(
        int256 totalOt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        uint256 timeToExpiry
    ) internal pure returns (uint256 lnImpliedRate) {
        // This will check for exchange rates < Math.IONE
        int256 exchangeRate = _getExchangeRate(totalOt, totalAsset, rateScalar, rateAnchor, 0);

        // exchangeRate >= 1 so its ln >= 0
        uint256 lnRate = exchangeRate.ln().Uint();

        lnImpliedRate = (lnRate * IMPLIED_RATE_TIME) / timeToExpiry;
    }

    /// @notice Converts an implied rate to an exchange rate given a time to expiry. The
    /// formula is E = e^rt
    function _getExchangeRateFromImpliedRate(uint256 lnImpliedRate, uint256 timeToExpiry)
        internal
        pure
        returns (int256 exchangeRate)
    {
        uint256 rt = (lnImpliedRate * timeToExpiry) / IMPLIED_RATE_TIME;

        exchangeRate = LogExpMath.exp(rt.Int());
    }

    function _getExchangeRate(
        int256 totalOt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        int256 netOtToAccount
    ) internal pure returns (int256 exchangeRate) {
        int256 numerator = totalOt.subNoNeg(netOtToAccount);

        int256 proportion = (numerator.divDown(totalOt + totalAsset));

        require(proportion <= MAX_MARKET_PROPORTION, "max proportion exceeded");

        int256 lnProportion = _logProportion(proportion);

        exchangeRate = lnProportion.divDown(rateScalar) + rateAnchor;

        require(exchangeRate >= Math.IONE, "exchange rate below 1");
    }

    function _logProportion(int256 proportion) internal pure returns (int256 res) {
        require(proportion != Math.IONE, "proportion must not be one");

        int256 logitP = proportion.divDown(Math.IONE - proportion);

        res = logitP.ln();
    }

    function _getRateScalar(MarketState memory market, uint256 timeToExpiry)
        internal
        pure
        returns (int256 rateScalar)
    {
        rateScalar = (market.scalarRoot * IMPLIED_RATE_TIME.Int()) / timeToExpiry.Int();
        require(rateScalar > 0, "rateScalar underflow");
    }

    function setInitialLnImpliedRate(
        MarketState memory market,
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
        market.lastLnImpliedRate = _getLnImpliedRate(
            market.totalOt,
            totalAsset,
            rateScalar,
            initialAnchor,
            market.expiry - blockTime
        );
    }

    function updateNewRateOracle(MarketState memory market, uint256 blockTime)
        internal
        pure
        returns (uint256)
    {
        // This can occur when using a view function get to a market state in the past
        if (market.lastTradeTime > blockTime) {
            market.oracleRate = market.lastLnImpliedRate;
            return market.oracleRate;
        }

        uint256 timeDiff = blockTime - market.lastTradeTime;
        if (timeDiff > market.rateOracleTimeWindow) {
            // If past the time window just return the market.lastLnImpliedRate
            market.oracleRate = market.lastLnImpliedRate;
            return market.oracleRate;
        }

        // (currentTs - previousTs) / timeWindow
        uint256 lastTradeWeight = timeDiff.divDown(market.rateOracleTimeWindow);

        // 1 - (currentTs - previousTs) / timeWindow
        uint256 oracleWeight = Math.ONE - lastTradeWeight;

        uint256 newOracleRate = market.lastTradeTime.mulDown(lastTradeWeight) +
            market.oracleRate.mulDown(oracleWeight);

        market.oracleRate = newOracleRate;
        return market.oracleRate;
    }
}
