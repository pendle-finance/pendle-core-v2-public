// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../LiquidYieldToken/ILiquidYieldToken.sol";
import "../../interfaces/IPMarket.sol";
import "./FixedPoint.sol";
import "./LogExpMath.sol";

struct MarketParameters {
    uint256 expiry;
    uint256 totalOt;
    uint256 totalLyt;
    uint256 totalLp;
    uint256 lastImpliedRate;
    uint256 lytRate;
    uint256 reserveFeePercent; // base 100
    uint256 scalarRoot;
    uint256 feeRateRoot;
    int256 anchorRoot;
    // if this is changed, change deepCloneMarket as well
}

// make sure this struct use minimal number of slots
struct MarketStorage {
    uint128 totalOt;
    uint128 totalLyt;
    uint32 lastImpliedRate; // is 32 bit enough?
}

// solhint-disable reason-string, ordering
library MarketMathLib {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for int256;
    struct NetTo {
        int256 toAccount;
        int256 toMarket;
        uint256 toReserve;
    }

    uint256 internal constant MINIMUM_LIQUIDITY = 10**3;
    uint256 internal constant DAY = 86400;
    uint256 internal constant IMPLIED_RATE_TIME = 360 * DAY;
    uint256 internal constant PERCENTAGE_DECIMALS = 100;

    // TODO: make sure 1e18 == FixedPoint.ONE
    uint256 internal constant MAX_MARKET_PROPORTION = (1e18 * 96) / 100;

    function setInitialImpliedRate(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
    {
        uint256 totalCashUnderlying = market.totalLyt.mulDown(market.lytRate);
        market.lastImpliedRate = getImpliedRate(
            market.totalOt,
            totalCashUnderlying,
            market.scalarRoot,
            market.anchorRoot,
            timeToExpiry
        );
    }

    function addLiquidity(
        MarketParameters memory market,
        uint256 lytDesired,
        uint256 otDesired
    )
        internal
        pure
        returns (
            uint256 lpToReserve,
            uint256 lpToUser,
            uint256 lytNeed,
            uint256 otNeed
        )
    {
        require(lytDesired > 0 && otDesired > 0, "ZERO_AMOUNTS");

        if (market.totalLp == 0) {
            lpToUser = lytDesired.mulDown(market.lytRate) - MINIMUM_LIQUIDITY;
            lpToReserve = MINIMUM_LIQUIDITY;
            lytNeed = lytDesired;
            otNeed = otDesired;
        } else {
            lpToUser = FixedPoint.min(
                (otDesired * market.totalLp) / market.totalOt,
                (lytDesired * market.totalLp) / market.totalLyt
            );
            lytNeed = (lytDesired * lpToUser) / market.totalLp;
            otNeed = (otDesired * lpToUser) / market.totalLp;
        }

        market.totalLyt += lytNeed;
        market.totalOt += otNeed;
        market.totalLp += lpToUser + lpToReserve;

        require(lpToUser > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
    }

    function removeLiquidity(MarketParameters memory market, uint256 lpToRemove)
        internal
        pure
        returns (uint256 lytOut, uint256 otOut)
    {
        require(lpToRemove > 0, "ZERO_LP");

        lytOut = (market.totalLp * market.totalOt) / market.totalLp;
        otOut = (market.totalLp * market.totalLyt) / market.totalLp;

        market.totalLp = market.totalLp - lpToRemove;
        market.totalOt = market.totalOt - otOut;
        market.totalLyt = market.totalLyt - lytOut;
    }

    /// @notice Calculates the asset cash amount the results from trading otToAccount with the market. A positive
    /// otToAccount is equivalent of lending, a negative is borrowing. Updates the market state in memory.
    /// @param market the current market state
    /// @param otToAccount the ot amount that will be deposited into the user's portfolio. The net change
    /// to the market is in the opposite direction.
    /// @param timeToExpiry number of seconds until expiry
    /// @return netLytToAccount netLytToReserve
    function calculateTrade(
        MarketParameters memory market,
        int256 otToAccount,
        uint256 timeToExpiry
    ) internal pure returns (int256 netLytToAccount, uint256 netLytToReserve) {
        require(timeToExpiry < market.expiry, "MARKET_EXPIRED");
        // We return false if there is not enough Ot to support this trade.
        // if otToAccount > 0 and totalOt - otToAccount <= 0 then the trade will fail
        // if otToAccount < 0 and totalOt > 0 then this will always pass
        require(market.totalOt.toInt() > otToAccount);

        // Calculates initial rate factors for the trade
        (uint256 scalar, uint256 totalCashUnderlying, int256 anchor) = getExchangeRateFactors(
            market,
            timeToExpiry
        );

        // Calculates the exchange rate from cash to Ot before any liquidity fees
        // are applied
        uint256 preFeeExchangeRate;
        {
            preFeeExchangeRate = _getExchangeRate(
                market.totalOt,
                totalCashUnderlying,
                scalar,
                anchor,
                otToAccount
            );
        }

        NetTo memory netCash;
        // Given the exchange rate, returns the net cash amounts to apply to each of the
        // three relevant balances.
        (netCash.toAccount, netCash.toMarket, netCash.toReserve) = _getNetCashAmountsUnderlying(
            market.feeRateRoot,
            preFeeExchangeRate,
            otToAccount,
            timeToExpiry,
            market.reserveFeePercent
        );

        {
            // Set the new implied interest rate after the trade has taken effect, this
            // will be used to calculate the next trader's interest rate.
            market.totalOt = (market.totalOt.toInt() - otToAccount).toUint();
            market.lastImpliedRate = getImpliedRate(
                market.totalOt,
                (totalCashUnderlying.toInt() + netCash.toMarket).toUint(),
                scalar,
                anchor,
                timeToExpiry
            );

            // It's technically possible that the implied rate is actually exactly zero (or
            // more accurately the natural log rounds down to zero) but we will still fail
            // in this case. If this does happen we may assume that markets are not initialized.
            require(market.lastImpliedRate != 0);
        }

        (netLytToAccount, netLytToReserve) = _setNewMarketState(
            market,
            netCash.toAccount,
            netCash.toMarket,
            netCash.toReserve
        );
    }

    /// @notice Returns factors for calculating exchange rates
    /// @return scalar a scalar value in rate precision that defines the slope of the line
    /// @return totalCashUnderlying the converted asset cash to underlying cash for calculating
    ///    the exchange rates for the trade
    /// @return anchor an offset from the x axis to maintain interest rate continuity over time
    // TODO: should we call the underlyingUnit to be accounting unit or cash?
    // TODO: convert all market.totalLyt.mulDown to a function

    function getExchangeRateFactors(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
        returns (
            uint256 scalar,
            uint256 totalCashUnderlying,
            int256 anchor
        )
    {
        scalar = getScalar(market, timeToExpiry);
        totalCashUnderlying = market.totalLyt.mulDown(market.lytRate);

        require(market.totalOt != 0 && totalCashUnderlying != 0);

        // Get the rate anchor given the market state, this will establish the baseline for where
        // the exchange rate is set.
        anchor;
        {
            anchor = _getAnchor(
                market.totalOt,
                market.lastImpliedRate,
                totalCashUnderlying,
                scalar,
                timeToExpiry
            );
        }
    }

    /// @dev Returns net asset cash amounts to the account, the market and the reserve
    /// @return netCashToAccount this is a positive or negative amount of cash change to the account
    /// @return netCashToMarket this is a positive or negative amount of cash change in the market
    /// @return netCashToReserve this is always a positive amount of cash accrued to the reserve
    function _getNetCashAmountsUnderlying(
        uint256 feeRateRoot,
        uint256 preFeeExchangeRate,
        int256 otToAccount,
        uint256 timeToExpiry,
        uint256 reserveFeePercent
    )
        private
        pure
        returns (
            int256 netCashToAccount,
            int256 netCashToMarket,
            uint256 netCashToReserve
        )
    {
        // Fees are specified in basis points which is an rate precision denomination. We convert this to
        // an exchange rate denomination for the given time to expiry. (i.e. get e^(fee * t) and multiply
        // or divide depending on the side of the trade).
        // tradeExchangeRate = exp((tradeInterestRateNoFee +/- fee) * timeToExpiry)
        // tradeExchangeRate = tradeExchangeRateNoFee (* or /) exp(fee * timeToExpiry)
        // cash = ot / exchangeRate, exchangeRate > 1
        int256 preFeeCashToAccount = otToAccount.divDown(preFeeExchangeRate).neg();
        uint256 feeRate = getExchangeRateFromImpliedRate(feeRateRoot, timeToExpiry);
        uint256 fee;

        if (otToAccount > 0) {
            // Lending
            // Dividing reduces exchange rate, lending should receive less ot for cash
            uint256 postFeeExchangeRate = preFeeExchangeRate.divDown(fee);
            // It's possible that the fee pushes exchange rates into negative territory. This is not possible
            // when borrowing. If this happens then the trade has failed.
            require(postFeeExchangeRate >= FixedPoint.ONE);

            // cashToAccount = -(otToAccount / exchangeRate)
            // postFeeExchangeRate = preFeeExchangeRate / feeExchangeRate
            // preFeeCashToAccount = -(otToAccount / preFeeExchangeRate)
            // postFeeCashToAccount = -(otToAccount / postFeeExchangeRate)
            // netFee = preFeeCashToAccount - postFeeCashToAccount
            // netFee = (otToAccount / postFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = ((otToAccount * feeExchangeRate) / preFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = (otToAccount / preFeeExchangeRate) * (feeExchangeRate - 1)
            // netFee = -(preFeeCashToAccount) * (feeExchangeRate - 1)
            // netFee = preFeeCashToAccount * (1 - feeExchangeRate)
            // RATE_PRECISION - fee will be negative here, preFeeCashToAccount < 0, fee > 0
            fee = preFeeCashToAccount.toUint().mulDown(FixedPoint.ONE - fee);
        } else {
            // Borrowing
            // cashToAccount = -(otToAccount / exchangeRate)
            // postFeeExchangeRate = preFeeExchangeRate * feeExchangeRate

            // netFee = preFeeCashToAccount - postFeeCashToAccount
            // netFee = (otToAccount / postFeeExchangeRate) - (otToAccount / preFeeExchangeRate)
            // netFee = ((otToAccount / (feeExchangeRate * preFeeExchangeRate)) - (otToAccount / preFeeExchangeRate)
            // netFee = (otToAccount / preFeeExchangeRate) * (1 / feeExchangeRate - 1)
            // netFee = preFeeCashToAccount * ((1 - feeExchangeRate) / feeExchangeRate)
            // NOTE: preFeeCashToAccount is negative in this branch so we negate it to ensure that fee is a positive number
            // preFee * (1 - fee) / fee will be negative, use neg() to flip to positive
            // RATE_PRECISION - fee will be negative
            fee = ((preFeeCashToAccount * ((FixedPoint.ONE - fee).toInt())) / feeRate.toInt())
                .neg()
                .toUint();
        }

        netCashToReserve = (fee * reserveFeePercent) / PERCENTAGE_DECIMALS;

        // postFeeCashToAccount = preFeeCashToAccount - fee
        netCashToAccount = preFeeCashToAccount - fee.toInt();
        netCashToMarket = (preFeeCashToAccount - fee.toInt() + netCashToReserve.toInt()).neg();
    }

    /// @notice Sets the new market state
    /// @return
    ///     netLytToAccount the positive or negative change in asset cash to the account
    ///     netLytToReserve the positive amount of cash that accrues to the reserve
    function _setNewMarketState(
        MarketParameters memory market,
        int256 netCashToAccount,
        int256 netCashToMarket,
        uint256 netCashToReserve
    ) private pure returns (int256 netLytToAccount, uint256 netLytToReserve) {
        int256 netLytToMarket = netCashToMarket.divDown(market.lytRate);
        // Set storage checks that total asset cash is above zero
        market.totalLyt = (market.totalLyt.toInt() + netLytToMarket).toUint();

        netLytToReserve = netCashToReserve.divDown(market.lytRate);
        netLytToAccount = netCashToAccount.divDown(market.lytRate);
    }

    /// @notice Rate anchors update as the market gets closer to expiry. Rate anchors are not comparable
    /// across time or markets but implied rates are. The goal here is to ensure that the implied rate
    /// before and after the rate anchor update is the same. Therefore, the market will trade at the same implied
    /// rate that it last traded at. If these anchors do not update then it opens up the opportunity for arbitrage
    /// which will hurt the liquidity providers.
    ///
    /// The rate anchor will update as the market rolls down to expiry. The calculation is:
    /// newExchangeRate = e^(lastImpliedRate * timeToExpiry / Constants.IMPLIED_RATE_TIME)
    /// newAnchor = newExchangeRate - ln((proportion / (1 - proportion)) / scalar
    ///
    /// where:
    /// lastImpliedRate = ln(exchangeRate') * (Constants.IMPLIED_RATE_TIME / timeToExpiry')
    ///      (calculated when the last trade in the market was made)
    /// @return anchor the new rate anchor and a boolean that signifies success
    function _getAnchor(
        uint256 totalOt,
        uint256 lastImpliedRate,
        uint256 totalCashUnderlying,
        uint256 scalar,
        uint256 timeToExpiry
    ) internal pure returns (int256 anchor) {
        // This is the exchange rate at the new time to expiry
        uint256 newExchangeRate = getExchangeRateFromImpliedRate(lastImpliedRate, timeToExpiry);

        require(newExchangeRate >= FixedPoint.ONE);

        {
            // totalOt / (totalOt + totalCashUnderlying)
            uint256 proportion = totalOt.divDown(totalOt + totalCashUnderlying);

            int256 lnProportion = _logProportion(proportion);

            // newExchangeRate - ln(proportion / (1 - proportion)) / scalar
            anchor = newExchangeRate.toInt() - lnProportion.divDown(scalar);
        }
    }

    /// @notice Calculates the current market implied rate.
    /// @return impliedRate the implied rate and a bool that is true on success
    function getImpliedRate(
        uint256 totalOt,
        uint256 totalCashUnderlying,
        uint256 scalar,
        int256 anchor,
        uint256 timeToExpiry
    ) internal pure returns (uint256 impliedRate) {
        // This will check for exchange rates < Constants.RATE_PRECISION
        uint256 exchangeRate = _getExchangeRate(totalOt, totalCashUnderlying, scalar, anchor, 0);

        uint256 lnRate = exchangeRate.toInt().ln().toUint();

        // lnRate * IMPLIED_RATE_TIME / ttm
        impliedRate = (lnRate * IMPLIED_RATE_TIME) / timeToExpiry;

        // TODO: Probably this is not necessary
        require(impliedRate <= type(uint32).max);
    }

    /// @notice Converts an implied rate to an exchange rate given a time to expiry. The
    /// formula is E = e^rt
    function getExchangeRateFromImpliedRate(uint256 impliedRate, uint256 timeToExpiry)
        internal
        pure
        returns (uint256 extRate)
    {
        uint256 rt = (impliedRate * timeToExpiry) / IMPLIED_RATE_TIME;

        extRate = LogExpMath.exp(rt.toInt()).toUint();
    }

    function getOtGivenCashAmount(
        MarketParameters memory marketImmutable,
        int256 netLytToAccount,
        uint256 timeToExpiry,
        int256 netOtToAccountGuess,
        uint256 maxSlippage
    )
        internal
        pure
        returns (
            int256 netOtToAccount
        )
    {
        require((netLytToAccount > 0) != (netOtToAccountGuess > 0), "invalid guess");

        bool swapLytForOt = (netLytToAccount < 0);

        int256 maxDelta = netOtToAccount.abs().mulDown(maxSlippage);
        int256 low = netOtToAccountGuess - maxDelta;
        int256 high = netOtToAccountGuess + maxDelta;
        while (low != high) {
            int256 currentOtGuess = (low + high + 1) / 2;
            MarketParameters memory market = deepCloneMarket(marketImmutable);

            (int256 lytToAccountOutput, ) = calculateTrade(market, currentOtGuess, timeToExpiry);
            if (swapLytForOt) {
                /*
                * lytToAccount < 0 => lytToAccount increases means less lyt is used
                * we simple checks if the amount of lyt being used to buy OT is less than the amount
                of lyt allowed. If yes, we can buy at least the current amount of ot.
                Else, need to reduce.
                */
                bool isResultAcceptable = (lytToAccountOutput >= netLytToAccount);
                if (isResultAcceptable) low = currentOtGuess;
                else high = currentOtGuess - 1;
            } else {
                /*
                * lytToAccount > 0 => lytToAccount increases means more lyt is used
                * currentOtGuess < 0 => currentOtGuess increases means less ot is sold
                * we simple checks if the amount of lyt receiving is at least the amount of lyt desired.
                If yes, we can sell at most the current amount of ot. Else, sell more
                */
                bool isResultAcceptable = (lytToAccountOutput >= netLytToAccount);
                if (isResultAcceptable) low = currentOtGuess;
                else high = currentOtGuess - 1;
            }
        }
    }

    function deepCloneMarket(MarketParameters memory marketImmutable)
        internal
        pure
        returns (MarketParameters memory market)
    {
        market.expiry = marketImmutable.expiry;
        market.totalOt = marketImmutable.totalOt;
        market.totalLyt = marketImmutable.totalLyt;
        market.totalLp = marketImmutable.totalLp;
        market.lastImpliedRate = marketImmutable.lastImpliedRate;
        market.lytRate = marketImmutable.lytRate;
        market.reserveFeePercent = marketImmutable.reserveFeePercent;
        market.scalarRoot = marketImmutable.scalarRoot;
        market.feeRateRoot = marketImmutable.feeRateRoot;
        market.anchorRoot = marketImmutable.anchorRoot;
    }

    /// @notice Returns the exchange rate between ot and cash for the given market
    /// Calculates the following exchange rate:
    ///     (1 / scalar) * ln(proportion / (1 - proportion)) + anchor
    /// where:
    ///     proportion = totalOt / (totalOt + totalUnderlyingCash)
    /// @dev has an underscore to denote as private but is marked internal for the mock
    function _getExchangeRate(
        uint256 totalOt,
        uint256 totalCashUnderlying,
        uint256 scalar,
        int256 anchor,
        int256 otToAccount
    ) internal pure returns (uint256 extRate) {
        int256 numerator = totalOt.toInt().subNoNeg(otToAccount);

        // This is the proportion scaled by Constants.RATE_PRECISION
        // (totalOt + ot) / (totalOt + totalCashUnderlying)
        uint256 proportion = (numerator.divDown(totalOt + totalCashUnderlying)).toUint();

        // This limit is here to prevent the market from reaching extremely high interest rates via an
        // excessively large proportion (high amounts of ot relative to cash).
        // Market proportion can only increase via borrowing (ot is added to the market and cash is
        // removed). Over time, the returns from asset cash will slightly decrease the proportion (the
        // value of cash underlying in the market must be monotonically increasing). Therefore it is not
        // possible for the proportion to go over max market proportion unless borrowing occurs.
        require(proportion <= MAX_MARKET_PROPORTION); // probably not applicable to Pendle

        int256 lnProportion = _logProportion(proportion);

        // lnProportion / scalar + anchor
        // because eventually extRate must be >= 1, we can safely cast it toUint so in case of
        // underflow, it would fail earlier
        extRate = (lnProportion.divDown(scalar) + anchor).toUint();

        // Do not succeed if interest rates fall below 1
        require(extRate >= FixedPoint.ONE);
    }

    function _logProportion(uint256 proportion) internal pure returns (int256 res) {
        // This will result in divide by zero, short circuit
        require(proportion != FixedPoint.ONE);

        // Convert proportion to what is used inside the logit function (p / (1-p))
        uint256 logitP = proportion.divDown(FixedPoint.ONE - proportion);
        res = logitP.toInt().ln();
    }

    function getScalar(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
        returns (uint256 scalar)
    {
        scalar = (market.scalarRoot * IMPLIED_RATE_TIME) / timeToExpiry;
        require(scalar > 0); // dev: rate scalar underflow
    }
}
