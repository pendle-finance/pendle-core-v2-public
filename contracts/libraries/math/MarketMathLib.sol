// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../LiquidYieldToken/ILiquidYieldToken.sol";
import "../../interfaces/IPMarket.sol";
import "./FixedPoint.sol";
import "./LogExpMath.sol";
import "../../LiquidYieldToken/implementations/LYTUtils.sol";

struct MarketParameters {
    uint256 expiry;
    int256 totalOt;
    int256 totalLyt;
    int256 totalLp;
    uint256 lastImpliedRate;
    uint256 lytRate;
    int256 reserveFeePercent; // base 100
    int256 scalarRoot;
    uint256 feeRateRoot;
    int256 anchorRoot;
    // if this is changed, change deepCloneMarket as well
}

// make sure this struct use minimal number of slots
struct MarketStorage {
    int128 totalOt;
    int128 totalLyt;
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
        int256 toReserve;
    }

    int256 internal constant MINIMUM_LIQUIDITY = 10**3;
    int256 internal constant PERCENTAGE_DECIMALS = 100;
    uint256 internal constant DAY = 86400;
    uint256 internal constant IMPLIED_RATE_TIME = 360 * DAY;

    // TODO: make sure 1e18 == FixedPoint.ONE
    int256 internal constant MAX_MARKET_PROPORTION = (1e18 * 96) / 100;

    function addLiquidity(
        MarketParameters memory market,
        uint256 _lytDesired,
        uint256 _otDesired
    )
        internal
        pure
        returns (
            uint256 _lpToReserve,
            uint256 _lpToUser,
            uint256 _lytUsed,
            uint256 _otUsed
        )
    {
        int256 lytDesired = _lytDesired.Int();
        int256 otDesired = _otDesired.Int();
        int256 lpToReserve;
        int256 lpToUser;
        int256 lytUsed;
        int256 otUsed;

        require(lytDesired > 0 && otDesired > 0, "ZERO_AMOUNTS");

        if (market.totalLp == 0) {
            lpToUser = LYTUtils.lytToAsset(market.lytRate, lytDesired).subNoNeg(MINIMUM_LIQUIDITY);
            lpToReserve = MINIMUM_LIQUIDITY;
            lytUsed = lytDesired;
            otUsed = otDesired;
        } else {
            lpToUser = FixedPoint.min(
                (otDesired * market.totalLp) / market.totalOt,
                (lytDesired * market.totalLp) / market.totalLyt
            );
            lytUsed = (lytDesired * lpToUser) / market.totalLp;
            otUsed = (otDesired * lpToUser) / market.totalLp;
        }

        market.totalLyt += lytUsed;
        market.totalOt += otUsed;
        market.totalLp += lpToUser + lpToReserve;

        require(lpToUser > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        _lpToReserve = lpToReserve.Uint();
        _lpToUser = lpToUser.Uint();
        _lytUsed = lytUsed.Uint();
        _otUsed = otUsed.Uint();
    }

    function removeLiquidity(MarketParameters memory market, uint256 _lpToRemove)
        internal
        pure
        returns (uint256 _lytOut, uint256 _otOut)
    {
        int256 lpToRemove = _lpToRemove.Int();
        int256 lytOut;
        int256 otOut;

        require(lpToRemove > 0, "invalid lp amount");

        lytOut = (market.totalLp * market.totalOt) / market.totalLp;
        otOut = (market.totalLp * market.totalLyt) / market.totalLp;

        market.totalLp = market.totalLp.subNoNeg(lpToRemove);
        market.totalOt = market.totalOt.subNoNeg(otOut);
        market.totalLyt = market.totalLyt.subNoNeg(lytOut);

        _lytOut = lytOut.Uint();
        _otOut = otOut.Uint();
    }

    function calcExactOtForLyt(
        MarketParameters memory market,
        uint256 exactOtIn,
        uint256 timeToExpiry
    ) internal pure returns (uint256 netLytOut, uint256 netLytToReserve) {
        (int256 _netLytToAccount, int256 _netLytToReserve) = calcTrade(
            market,
            exactOtIn.neg(),
            timeToExpiry
        );
        netLytOut = _netLytToAccount.Uint();
        netLytToReserve = _netLytToReserve.Uint();
    }

    function calcLytForExactOt(
        MarketParameters memory market,
        uint256 exactOtOut,
        uint256 timeToExpiry
    ) internal pure returns (uint256 netLytIn, uint256 netLytToReserve) {
        (int256 _netLytToAccount, int256 _netLytToReserve) = calcTrade(
            market,
            exactOtOut.Int(),
            timeToExpiry
        );
        netLytIn = _netLytToAccount.neg().Uint();
        netLytToReserve = _netLytToReserve.Uint();
    }

    /// @notice Calculates the asset cash amount the results from trading otToAccount with the market. A positive
    /// otToAccount is equivalent of lending, a negative is borrowing. Updates the market state in memory.
    /// @param market the current market state
    /// @param otToAccount the ot amount that will be deposited into the user's portfolio. The net change
    /// to the market is in the opposite direction.
    /// @param timeToExpiry number of seconds until expiry
    /// @return netLytToAccount netLytToReserve
    function calcTrade(
        MarketParameters memory market,
        int256 otToAccount,
        uint256 timeToExpiry
    ) internal pure returns (int256 netLytToAccount, int256 netLytToReserve) {
        require(timeToExpiry < market.expiry, "MARKET_EXPIRED");
        // We return false if there is not enough Ot to support this trade.
        // if otToAccount > 0 and totalOt - otToAccount <= 0 then the trade will fail
        // if otToAccount < 0 and totalOt > 0 then this will always pass
        require(market.totalOt > otToAccount);

        // Calculates initial rate factors for the trade
        (
            int256 rateScalar,
            int256 totalCashUnderlying,
            int256 rateAnchor
        ) = getExchangeRateFactors(market, timeToExpiry);

        // Calculates the exchange rate from cash to Ot before any liquidity fees
        // are applied
        int256 preFeeExchangeRate;
        {
            preFeeExchangeRate = _getExchangeRate(
                market.totalOt,
                totalCashUnderlying,
                rateScalar,
                rateAnchor,
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
            market.totalOt = market.totalOt.subNoNeg(otToAccount);
            market.lastImpliedRate = getImpliedRate(
                market.totalOt,
                totalCashUnderlying + netCash.toMarket,
                rateScalar,
                rateAnchor,
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
    /// @return rateScalar a rateScalar value in rate precision that defines the slope of the line
    /// @return totalCashUnderlying the converted asset cash to underlying cash for calculating
    ///    the exchange rates for the trade
    /// @return rateAnchor an offset from the x axis to maintain interest rate continuity over time
    function getExchangeRateFactors(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
        returns (
            int256 rateScalar,
            int256 totalCashUnderlying,
            int256 rateAnchor
        )
    {
        rateScalar = getRateScalar(market, timeToExpiry);
        totalCashUnderlying = LYTUtils.lytToAsset(market.lytRate, market.totalLyt);

        require(market.totalOt != 0 && totalCashUnderlying != 0);

        // Get the rateAnchor given the market state, this will establish the baseline for where
        // the exchange rate is set.
        rateAnchor;
        {
            rateAnchor = _getRateAnchor(
                market.totalOt,
                market.lastImpliedRate,
                totalCashUnderlying,
                rateScalar,
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
        int256 preFeeExchangeRate,
        int256 otToAccount,
        uint256 timeToExpiry,
        int256 reserveFeePercent
    )
        private
        pure
        returns (
            int256 netCashToAccount,
            int256 netCashToMarket,
            int256 netCashToReserve
        )
    {
        // Fees are specified in basis points which is an rate precision denomination. We convert this to
        // an exchange rate denomination for the given time to expiry. (i.e. get e^(fee * t) and multiply
        // or divide depending on the side of the trade).
        // tradeExchangeRate = exp((tradeInterestRateNoFee +/- fee) * timeToExpiry)
        // tradeExchangeRate = tradeExchangeRateNoFee (* or /) exp(fee * timeToExpiry)
        // cash = ot / exchangeRate, exchangeRate > 1
        int256 preFeeCashToAccount = otToAccount.divDown(preFeeExchangeRate).neg();
        int256 feeRate = getExchangeRateFromImpliedRate(feeRateRoot, timeToExpiry);
        int256 fee;

        if (otToAccount > 0) {
            // Lending
            // Dividing reduces exchange rate, lending should receive less ot for cash
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(fee);
            // It's possible that the fee pushes exchange rates into negative territory. This is not possible
            // when borrowing. If this happens then the trade has failed.
            require(postFeeExchangeRate >= FixedPoint.ONE_INT);

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
            fee = preFeeCashToAccount.mulDown(FixedPoint.ONE_INT - fee);
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
            fee = ((preFeeCashToAccount * (FixedPoint.ONE_INT - fee)) / feeRate).neg();
        }

        netCashToReserve = (fee * reserveFeePercent) / PERCENTAGE_DECIMALS;

        // postFeeCashToAccount = preFeeCashToAccount - fee
        netCashToAccount = preFeeCashToAccount - fee;
        netCashToMarket = (preFeeCashToAccount - fee + netCashToReserve).neg();
    }

    /// @notice Sets the new market state
    /// @return
    ///     netLytToAccount the positive or negative change in asset cash to the account
    ///     netLytToReserve the positive amount of cash that accrues to the reserve
    function _setNewMarketState(
        MarketParameters memory market,
        int256 netCashToAccount,
        int256 netCashToMarket,
        int256 netCashToReserve
    ) private pure returns (int256 netLytToAccount, int256 netLytToReserve) {
        int256 netLytToMarket = LYTUtils.assetToLyt(market.lytRate, netCashToMarket);
        // Set storage checks that total asset cash is above zero
        market.totalLyt = market.totalLyt + netLytToMarket;

        netLytToReserve = LYTUtils.assetToLyt(market.lytRate, netCashToReserve);
        netLytToAccount = LYTUtils.assetToLyt(market.lytRate, netCashToAccount);
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
        int256 totalCashUnderlying,
        int256 rateScalar,
        uint256 timeToExpiry
    ) internal pure returns (int256 rateAnchor) {
        // This is the exchange rate at the new time to expiry
        int256 newExchangeRate = getExchangeRateFromImpliedRate(lastImpliedRate, timeToExpiry);

        require(newExchangeRate >= FixedPoint.ONE_INT);

        {
            // totalOt / (totalOt + totalCashUnderlying)
            int256 proportion = totalOt.divDown(totalOt + totalCashUnderlying);

            int256 lnProportion = _logProportion(proportion);

            // newExchangeRate - ln(proportion / (1 - proportion)) / rateScalar
            rateAnchor = newExchangeRate - lnProportion.divDown(rateScalar);
        }
    }

    /// @notice Calculates the current market implied rate.
    /// @return impliedRate the implied rate and a bool that is true on success
    function getImpliedRate(
        int256 totalOt,
        int256 totalCashUnderlying,
        int256 rateScalar,
        int256 rateAnchor,
        uint256 timeToExpiry
    ) internal pure returns (uint256 impliedRate) {
        // This will check for exchange rates < FixedPoint.ONE_INT
        int256 exchangeRate = _getExchangeRate(
            totalOt,
            totalCashUnderlying,
            rateScalar,
            rateAnchor,
            0
        );

        uint256 lnRate = exchangeRate.ln().Uint();

        impliedRate = (lnRate * IMPLIED_RATE_TIME) / timeToExpiry;

        // TODO: Probably this is not necessary
        require(impliedRate <= type(uint32).max);
    }

    /// @notice Converts an implied rate to an exchange rate given a time to expiry. The
    /// formula is E = e^rt
    function getExchangeRateFromImpliedRate(uint256 impliedRate, uint256 timeToExpiry)
        internal
        pure
        returns (int256 extRate)
    {
        // TODO: Double check this part
        uint256 rt = (impliedRate * timeToExpiry) / IMPLIED_RATE_TIME;

        extRate = LogExpMath.exp(rt.Int());
    }

    /// @notice Returns the exchange rate between ot and cash for the given market
    /// Calculates the following exchange rate:
    ///     (1 / rateScalar) * ln(proportion / (1 - proportion)) + rateAnchor
    /// where:
    ///     proportion = totalOt / (totalOt + totalUnderlyingCash)
    /// @dev has an underscore to denote as private but is marked internal for the mock
    function _getExchangeRate(
        int256 totalOt,
        int256 totalCashUnderlying,
        int256 rateScalar,
        int256 rateAnchor,
        int256 otToAccount
    ) internal pure returns (int256 extRate) {
        int256 numerator = totalOt.subNoNeg(otToAccount);

        // This is the proportion scaled by FixedPoint.ONE_INT
        // (totalOt + ot) / (totalOt + totalCashUnderlying)
        int256 proportion = (numerator.divDown(totalOt + totalCashUnderlying));

        // This limit is here to prevent the market from reaching extremely high interest rates via an
        // excessively large proportion (high amounts of ot relative to cash).
        // Market proportion can only increase via borrowing (ot is added to the market and cash is
        // removed). Over time, the returns from asset cash will slightly decrease the proportion (the
        // value of cash underlying in the market must be monotonically increasing). Therefore it is not
        // possible for the proportion to go over max market proportion unless borrowing occurs.
        require(proportion <= MAX_MARKET_PROPORTION); // probably not applicable to Pendle

        int256 lnProportion = _logProportion(proportion);

        // lnProportion / rateScalar + rateAnchor
        extRate = lnProportion.divDown(rateScalar) + rateAnchor;

        // Do not succeed if interest rates fall below 1
        require(extRate >= FixedPoint.ONE_INT);
    }

    function _logProportion(int256 proportion) internal pure returns (int256 res) {
        // This will result in divide by zero, short circuit
        require(proportion != FixedPoint.ONE_INT);

        // Convert proportion to what is used inside the logit function (p / (1-p))
        int256 logitP = proportion.divDown(FixedPoint.ONE_INT - proportion);

        res = logitP.ln();
    }

    function getSwapExactLytForOt(
        MarketParameters memory marketImmutable,
        uint256 exactLytIn,
        uint256 timeToExpiry,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) internal pure returns (uint256 netOtToAccount) {
        require(exactLytIn > 0, "invalid lyt in");
        require(netOtOutGuessMin >= 0 && netOtOutGuessMax >= 0, "invalid guess");

        uint256 low = netOtOutGuessMin;
        uint256 high = netOtOutGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentOtOutGuess = (low + high + 1) / 2;
            MarketParameters memory market = deepCloneMarket(marketImmutable);

            (int256 lytOwed, ) = calcTrade(market, currentOtOutGuess.Int(), timeToExpiry);
            bool isResultAcceptable = (lytOwed.abs() <= exactLytIn);
            if (isResultAcceptable) {
                low = currentOtOutGuess;
                isAcceptableAnswerExisted = true;
            } else high = currentOtOutGuess - 1;
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netOtToAccount = low;
    }

    function getSwapExactLytForYt(
        MarketParameters memory marketImmutable,
        uint256 exactLytIn,
        uint256 timeToExpiry,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) internal pure returns (uint256 netYtToAccount) {
        require(exactLytIn > 0, "invalid lyt in");
        require(netYtOutGuessMin >= 0 && netYtOutGuessMax >= 0, "invalid guess");

        uint256 low = netYtOutGuessMin;
        uint256 high = netYtOutGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentYtOutGuess = (low + high + 1) / 2;
            MarketParameters memory market = deepCloneMarket(marketImmutable);

            int256 otToAccount = currentYtOutGuess.neg();
            (int256 lytReceived, ) = calcTrade(market, otToAccount, timeToExpiry);

            int256 totalLytToMintYo = lytReceived + exactLytIn.Int();

            int256 netYoFromLyt = LYTUtils.lytToAsset(market.lytRate, totalLytToMintYo);

            bool isResultAcceptable = (netYoFromLyt.Uint() >= currentYtOutGuess);

            if (isResultAcceptable) {
                low = currentYtOutGuess;
                isAcceptableAnswerExisted = true;
            } else high = currentYtOutGuess - 1;
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netYtToAccount = low;
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

    function getRateScalar(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
        returns (int256 rateScalar)
    {
        rateScalar = (market.scalarRoot * IMPLIED_RATE_TIME.Int()) / timeToExpiry.Int();
        require(rateScalar > 0); // dev: rateScalar underflow
    }

    function setInitialImpliedRate(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
    {
        int256 totalCashUnderlying = LYTUtils.lytToAsset(market.lytRate, market.totalLyt);
        market.lastImpliedRate = getImpliedRate(
            market.totalOt,
            totalCashUnderlying,
            market.scalarRoot,
            market.anchorRoot,
            timeToExpiry
        );
    }
}
