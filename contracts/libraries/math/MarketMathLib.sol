// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../SuperComposableYield/ISuperComposableYield.sol";
import "../../interfaces/IPMarket.sol";
import "./FixedPoint.sol";
import "./LogExpMath.sol";
import "../SCYIndex.sol";

// if this is changed, change deepCloneMarket as well
struct MarketParameters {
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

struct MarketStorage {
    int128 totalOt;
    int128 totalScy;
    uint112 lastImpliedRate;
    uint112 oracleRate;
    uint32 lastTradeTime;
}

// solhint-disable reason-string, ordering
library MarketMathLib {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;

    struct NetTo {
        int256 toAccount;
        int256 toMarket;
        int256 toReserve;
    }

    struct ExecuteTradeSlot {
        uint256 timeToExpiry;
        int256 rateScalar;
        int256 totalAsset;
        int256 rateAnchor;
        int256 preFeeExchangeRate;
    }

    int256 internal constant MINIMUM_LIQUIDITY = 10**3;
    int256 internal constant PERCENTAGE_DECIMALS = 100;
    uint256 internal constant DAY = 86400;
    uint256 internal constant IMPLIED_RATE_TIME = 360 * DAY;

    int256 internal constant MAX_MARKET_PROPORTION = (1e18 * 96) / 100;

    function addLiquidity(
        MarketParameters memory market,
        SCYIndex index,
        uint256 scyDesired,
        uint256 otDesired
    )
        internal
        pure
        returns (
            uint256 lpToReserve,
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 otUsed
        )
    {
        (
            int256 _lpToReserve,
            int256 _lpToAccount,
            int256 _scyUsed,
            int256 _otUsed
        ) = _addLiquidity(market, index, scyDesired.Int(), otDesired.Int());

        lpToReserve = _lpToReserve.Uint();
        lpToAccount = _lpToAccount.Uint();
        scyUsed = _scyUsed.Uint();
        otUsed = _otUsed.Uint();
    }

    function removeLiquidity(MarketParameters memory market, uint256 lpToRemove)
        internal
        pure
        returns (uint256 scyToAccount, uint256 otToAccount)
    {
        (int256 _scyToAccount, int256 _otToAccount) = _removeLiquidity(market, lpToRemove.Int());

        scyToAccount = _scyToAccount.Uint();
        otToAccount = _otToAccount.Uint();
    }

    function swapExactOtForScy(
        MarketParameters memory market,
        SCYIndex index,
        uint256 exactOtToMarket,
        uint256 blockTime
    ) internal pure returns (uint256 netScyToAccount, uint256 netScyToReserve) {
        (int256 _netScyToAccount, int256 _netScyToReserve) = _executeTrade(
            market,
            index,
            exactOtToMarket.neg(),
            blockTime
        );

        netScyToAccount = _netScyToAccount.Uint();
        netScyToReserve = _netScyToReserve.Uint();
    }

    function swapScyForExactOt(
        MarketParameters memory market,
        SCYIndex index,
        uint256 exactOtToAccount,
        uint256 blockTime
    ) internal pure returns (uint256 netScyToMarket, uint256 netScyToReserve) {
        (int256 _netScyToAccount, int256 _netScyToReserve) = _executeTrade(
            market,
            index,
            exactOtToAccount.Int(),
            blockTime
        );

        netScyToMarket = _netScyToAccount.neg().Uint();
        netScyToReserve = _netScyToReserve.Uint();
    }

    function setInitialImpliedRate(
        MarketParameters memory market,
        SCYIndex index,
        int256 initialAnchor,
        uint256 blockTime
    ) internal pure {
        require(blockTime < market.expiry, "market expired");
        int256 totalAsset = index.scyToAsset(market.totalScy);
        uint256 timeToExpiry = market.expiry - blockTime;
        int256 rateScalar = _getRateScalar(market, timeToExpiry);
        market.lastImpliedRate = _getImpliedRate(
            market.totalOt,
            totalAsset,
            rateScalar,
            initialAnchor,
            market.expiry - blockTime
        );
    }

    function updateNewRateOracle(MarketParameters memory market, uint256 blockTime)
        internal
        pure
        returns (uint256)
    {
        // require(rateOracleTimeWindow > 0); // dev: update rate oracle, time window zero

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

    /*///////////////////////////////////////////////////////////////
                    END OF HIGH LEVEL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _addLiquidity(
        MarketParameters memory market,
        SCYIndex index,
        int256 scyDesired,
        int256 otDesired
    )
        private
        pure
        returns (
            int256 lpToReserve,
            int256 lpToAccount,
            int256 scyUsed,
            int256 otUsed
        )
    {
        require(scyDesired > 0 && otDesired > 0, "ZERO_AMOUNTS");

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

        market.totalScy += scyUsed;
        market.totalOt += otUsed;
        market.totalLp += lpToAccount + lpToReserve;
    }

    function _removeLiquidity(MarketParameters memory market, int256 lpToRemove)
        private
        pure
        returns (int256 scyToAccount, int256 otToAccount)
    {
        require(lpToRemove > 0, "invalid lp amount");

        scyToAccount = (lpToRemove * market.totalScy) / market.totalLp;
        otToAccount = (lpToRemove * market.totalOt) / market.totalLp;

        market.totalLp = market.totalLp.subNoNeg(lpToRemove);
        market.totalOt = market.totalOt.subNoNeg(otToAccount);
        market.totalScy = market.totalScy.subNoNeg(scyToAccount);
    }

    /// @notice Calculates the asset amount the results from trading otToAccount with the market. A positive
    /// otToAccount is equivalent of swapping OT into the market, a negative is taking OT out.
    /// Updates the market state in memory.
    /// @param market the current market state
    /// @param otToAccount the OT amount that will be deposited into the user's portfolio. The net change
    /// to the market is in the opposite direction.
    /// @return netScyToAccount netScyToReserve
    function _executeTrade(
        MarketParameters memory market,
        SCYIndex index,
        int256 otToAccount,
        uint256 blockTime
    ) private pure returns (int256 netScyToAccount, int256 netScyToReserve) {
        require(blockTime < market.expiry, "market expired");

        ExecuteTradeSlot memory slot;
        slot.timeToExpiry = market.expiry - blockTime;

        // We return false if there is not enough Ot to support this trade.
        // if otToAccount > 0 and totalOt - otToAccount <= 0 then the trade will fail
        // if otToAccount < 0 and totalOt > 0 then this will always pass
        require(market.totalOt > otToAccount, "insufficient liquidity");

        // Calculates initial rate factors for the trade
        (slot.rateScalar, slot.totalAsset, slot.rateAnchor) = _getExchangeRateFactors(
            market,
            index,
            slot.timeToExpiry
        );

        // Calculates the exchange rate from Asset to OT before any liquidity fees
        // are applied
        slot.preFeeExchangeRate = _getExchangeRate(
            market.totalOt,
            slot.totalAsset,
            slot.rateScalar,
            slot.rateAnchor,
            otToAccount
        );

        NetTo memory netAsset;
        // Given the exchange rate, returns the netAsset amounts to apply to each of the
        // three relevant balances.
        (
            netAsset.toAccount,
            netAsset.toMarket,
            netAsset.toReserve
        ) = _getNetAssetAmountsToAddresses(
            market.feeRateRoot,
            slot.preFeeExchangeRate,
            otToAccount,
            slot.timeToExpiry,
            market.reserveFeePercent
        );

        //////////////////////////////////
        /// Update params in the market///
        ///////////////////////////////x///
        // Set the new implied interest rate after the trade has taken effect, this
        // will be used to calculate the next trader's interest rate.
        market.totalOt = market.totalOt.subNoNeg(otToAccount);
        market.lastImpliedRate = _getImpliedRate(
            market.totalOt,
            slot.totalAsset + netAsset.toMarket,
            slot.rateScalar,
            slot.rateAnchor,
            slot.timeToExpiry
        );

        // It's technically possible that the implied rate is actually exactly zero (or
        // more accurately the natural log rounds down to zero) but we will still fail
        // in this case. If this does happen we may assume that markets are not initialized.
        require(market.lastImpliedRate != 0);

        (netScyToAccount, netScyToReserve) = _setNewMarketState(
            market,
            index,
            netAsset.toAccount,
            netAsset.toMarket,
            netAsset.toReserve,
            blockTime
        );
    }

    /// @notice Returns factors for calculating exchange rates
    /// @return rateScalar a value in rate precision that defines the slope of the line
    /// @return totalAsset the converted SCY to Asset for calculatin the exchange rates for the trade
    /// @return rateAnchor an offset from the x axis to maintain interest rate continuity over time
    function _getExchangeRateFactors(
        MarketParameters memory market,
        SCYIndex index,
        uint256 timeToExpiry
    )
        private
        pure
        returns (
            int256 rateScalar,
            int256 totalAsset,
            int256 rateAnchor
        )
    {
        rateScalar = _getRateScalar(market, timeToExpiry);
        totalAsset = index.scyToAsset(market.totalScy);

        require(market.totalOt != 0 && totalAsset != 0);

        // Get the rateAnchor given the market state, this will establish the baseline for where
        // the exchange rate is set.
        {
            rateAnchor = _getRateAnchor(
                market.totalOt,
                market.lastImpliedRate,
                totalAsset,
                rateScalar,
                timeToExpiry
            );
        }
    }

    /// @dev Returns net Asset amounts to the account, the market and the reserve. netAssetToReserve
    /// is actually the fee portion of the trade
    /// @return netAssetToAccount this is a positive or negative amount of Asset change to the account
    /// @return netAssetToMarket this is a positive or negative amount of Asset change in the market
    /// @return netAssetToReserve this is always a positive amount of Asset accrued to the reserve
    function _getNetAssetAmountsToAddresses(
        uint256 feeRateRoot,
        int256 preFeeExchangeRate,
        int256 otToAccount,
        uint256 timeToExpiry,
        int256 reserveFeePercent
    )
        private
        pure
        returns (
            int256 netAssetToAccount,
            int256 netAssetToMarket,
            int256 netAssetToReserve
        )
    {
        // Fees are specified in basis points which is an rate precision denomination. We convert this to
        // an exchange rate denomination for the given time to expiry. (i.e. get e^(fee * t) and multiply
        // or divide depending on the side of the trade).
        // tradeExchangeRate = exp((tradeInterestRateNoFee +/- fee) * timeToExpiry)
        // tradeExchangeRate = tradeExchangeRateNoFee (* or /) exp(fee * timeToExpiry)
        // Asset = OT / exchangeRate, exchangeRate > 1
        int256 preFeeAssetToAccount = otToAccount.divDown(preFeeExchangeRate).neg();
        int256 fee = _getExchangeRateFromImpliedRate(feeRateRoot, timeToExpiry);

        if (otToAccount > 0) {
            // swapping SCY for OT

            // Dividing reduces exchange rate, swapping SCY to OT means account should receive less OT
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(fee);
            // It's possible that the fee pushes exchange rates into negative territory. This is not possible
            // when swapping OT to SCY. If this happens then the trade has failed.
            require(postFeeExchangeRate >= FixedPoint.ONE_INT, "exchange rate below 1");

            // assetToAccount = -(otToAccount / exchangeRate)
            // postFeeExchangeRate = preFeeExchangeRate / feeExchangeRate
            // preFeeAssetToAccount = -(otToAccount / preFeeExchangeRate)
            // postFeeAssetToAccount = -(otToAccount / postFeeExchangeRate)
            // netFee = preFeeAssetToAccount - postFeeAssetToAccount
            // netFee = (otToAccount / postFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = ((otToAccount * feeExchangeRate) / preFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = (otToAccount / preFeeExchangeRate) * (feeExchangeRate - 1)
            // netFee = -(preFeeAssetToAccount) * (feeExchangeRate - 1)
            // netFee = preFeeAssetToAccount * (1 - feeExchangeRate)
            // RATE_PRECISION - fee will be negative here, preFeeAssetToAccount < 0, fee > 0
            fee = preFeeAssetToAccount.mulDown(FixedPoint.ONE_INT - fee);
        } else {
            // swapping OT for SCY

            // assetToAccount = -(otToAccount / exchangeRate)
            // postFeeExchangeRate = preFeeExchangeRate * feeExchangeRate

            // netFee = preFeeAssetToAccount - postFeeAssetToAccount
            // netFee = (otToAccount / postFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = ((otToAccount / (feeExchangeRate * preFeeExchangeRate)) - (otToAccount / preFeeExchangeRate)
            // netFee = (otToAccount / preFeeExchangeRate) * (1 / feeExchangeRate - 1)
            // netFee = preFeeAssetToAccount * ((1 - feeExchangeRate) / feeExchangeRate)
            // NOTE: preFeeAssetToAccount is negative in this branch so we negate it to ensure that fee is a positive number
            // preFee * (1 - fee) / fee will be negative, use neg() to flip to positive
            // RATE_PRECISION - fee will be negative
            fee = ((preFeeAssetToAccount * (FixedPoint.ONE_INT - fee)) / fee).neg();
        }

        netAssetToReserve = (fee * reserveFeePercent) / PERCENTAGE_DECIMALS;

        // postFeeAssetToAccount = preFeeAssetToAccount - fee
        netAssetToAccount = preFeeAssetToAccount - fee;
        netAssetToMarket = (preFeeAssetToAccount - fee + netAssetToReserve).neg();
    }

    /// @notice Sets the new market state
    /// @return netScyToAccount the positive or negative change in asset scy to the account
    /// @return netScyToReserve the positive amount of scy that accrues to the reserve
    function _setNewMarketState(
        MarketParameters memory market,
        SCYIndex index,
        int256 netAssetToAccount,
        int256 netAssetToMarket,
        int256 netAssetToReserve,
        uint256 blockTime
    ) private pure returns (int256 netScyToAccount, int256 netScyToReserve) {
        int256 netScyToMarket = index.assetToScy(netAssetToMarket);
        // Set storage checks that total asset scy is above zero
        market.totalScy = market.totalScy + netScyToMarket;

        market.lastTradeTime = blockTime;
        netScyToReserve = index.assetToScy(netAssetToReserve);
        netScyToAccount = index.assetToScy(netAssetToAccount);
    }

    /// @notice Rate anchors update as the market gets closer to expiry. Rate anchors are not comparable
    /// across time or markets but implied rates are. The goal here is to ensure that the implied rate
    /// before and after the rate anchor update is the same. Therefore, the market will trade at the same implied
    /// rate that it last traded at. If these anchors do not update then it opens up the opportunity for arbitrage
    /// which will hurt the liquidity providers.
    ///
    /// The rate anchor will update as the market rolls down to expiry. The calculation is:
    /// newExchangeRate = e^(lastImpliedRate * timeToExpiry / Constants.IMPLIED_RATE_TIME)
    /// newAnchor = newExchangeRate - ln((proportion / (1 - proportion)) / rateScalar
    ///
    /// where:
    /// lastImpliedRate = ln(exchangeRate') * (Constants.IMPLIED_RATE_TIME / timeToExpiry')
    ///      (calculated when the last trade in the market was made)
    /// @return rateAnchor the new rateAnchor
    function _getRateAnchor(
        int256 totalOt,
        uint256 lastImpliedRate,
        int256 totalAsset,
        int256 rateScalar,
        uint256 timeToExpiry
    ) private pure returns (int256 rateAnchor) {
        // This is the exchange rate at the new time to expiry
        int256 newExchangeRate = _getExchangeRateFromImpliedRate(lastImpliedRate, timeToExpiry);

        require(newExchangeRate >= FixedPoint.ONE_INT, "exchange rate below 1");

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
    ) private pure returns (uint256 impliedRate) {
        // This will check for exchange rates < FixedPoint.ONE_INT
        int256 exchangeRate = _getExchangeRate(totalOt, totalAsset, rateScalar, rateAnchor, 0);

        // exchangeRate >= 1 so its ln >= 0
        uint256 lnRate = exchangeRate.ln().Uint();

        impliedRate = (lnRate * IMPLIED_RATE_TIME) / timeToExpiry;
    }

    /// @notice Converts an implied rate to an exchange rate given a time to expiry. The
    /// formula is E = e^rt
    function _getExchangeRateFromImpliedRate(uint256 impliedRate, uint256 timeToExpiry)
        private
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
        int256 otToAccount
    ) private pure returns (int256 exchangeRate) {
        int256 numerator = totalOt.subNoNeg(otToAccount);

        // This is the proportion scaled by FixedPoint.ONE_INT
        // (totalOt + otToMarket) / (totalOt + totalAsset)
        int256 proportion = (numerator.divDown(totalOt + totalAsset));

        // This limit is here to prevent the market from reaching extremely high interest rates via an
        // excessively large proportion (high amounts of OT relative to Asset).
        // Market proportion can only increase via swapping OT to SCY (OT is added to the market and SCY is
        // removed). Over time, the yield from SCY will slightly decrease the proportion (the
        // amount of Asset in the market must be monotonically increasing). Therefore it is not
        // possible for the proportion to go over max market proportion unless borrowing occurs.
        require(proportion <= MAX_MARKET_PROPORTION);

        int256 lnProportion = _logProportion(proportion);

        // lnProportion / rateScalar + rateAnchor
        exchangeRate = lnProportion.divDown(rateScalar) + rateAnchor;

        // Do not succeed if interest rates fall below 1
        require(exchangeRate >= FixedPoint.ONE_INT, "exchange rate below 1");
    }

    function _logProportion(int256 proportion) private pure returns (int256 res) {
        // This will result in divide by zero, short circuit
        require(proportion != FixedPoint.ONE_INT);

        // Convert proportion to what is used inside the logit function (p / (1-p))
        int256 logitP = proportion.divDown(FixedPoint.ONE_INT - proportion);

        res = logitP.ln();
    }

    function _getRateScalar(MarketParameters memory market, uint256 timeToExpiry)
        private
        pure
        returns (int256 rateScalar)
    {
        rateScalar = (market.scalarRoot * IMPLIED_RATE_TIME.Int()) / timeToExpiry.Int();
        require(rateScalar > 0, "rateScalar underflow");
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                    Utility functions                                    ////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    // function timeToExpiry(MarketParameters memory market) internal view returns (uint256) {
    //     unchecked {
    //         require(block.timestamp <= market.expiry, "market expired");
    //         return market.expiry - block.timestamp;
    //     }
    // }

    function deepCloneMarket(MarketParameters memory marketImmutable)
        internal
        pure
        returns (MarketParameters memory market)
    {
        market.totalOt = marketImmutable.totalOt;
        market.totalScy = marketImmutable.totalScy;
        market.totalLp = marketImmutable.totalLp;
        market.oracleRate = marketImmutable.oracleRate;
        market.scalarRoot = marketImmutable.scalarRoot;
        market.feeRateRoot = marketImmutable.feeRateRoot;
        market.rateOracleTimeWindow = marketImmutable.rateOracleTimeWindow;
        market.expiry = marketImmutable.expiry;
        market.reserveFeePercent = marketImmutable.reserveFeePercent;
        market.lastImpliedRate = marketImmutable.lastImpliedRate;
        market.lastTradeTime = marketImmutable.lastTradeTime;
    }
}
