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
            uint256 _lpToAccount,
            uint256 _lytUsed,
            uint256 _otUsed
        )
    {
        int256 lytDesired = _lytDesired.Int();
        int256 otDesired = _otDesired.Int();
        int256 lpToReserve;
        int256 lpToAccount;
        int256 lytUsed;
        int256 otUsed;

        require(lytDesired > 0 && otDesired > 0, "ZERO_AMOUNTS");

        if (market.totalLp == 0) {
            lpToAccount = LYTUtils.lytToAsset(market.lytRate, lytDesired).subNoNeg(
                MINIMUM_LIQUIDITY
            );
            lpToReserve = MINIMUM_LIQUIDITY;
            lytUsed = lytDesired;
            otUsed = otDesired;
        } else {
            lpToAccount = FixedPoint.min(
                (otDesired * market.totalLp) / market.totalOt,
                (lytDesired * market.totalLp) / market.totalLyt
            );
            lytUsed = (lytDesired * lpToAccount) / market.totalLp;
            otUsed = (otDesired * lpToAccount) / market.totalLp;
        }

        market.totalLyt += lytUsed;
        market.totalOt += otUsed;
        market.totalLp += lpToAccount + lpToReserve;

        require(lpToAccount > 0, "INSUFFICIENT_LIQUIDITY_MINTED");

        _lpToReserve = lpToReserve.Uint();
        _lpToAccount = lpToAccount.Uint();
        _lytUsed = lytUsed.Uint();
        _otUsed = otUsed.Uint();
    }

    function removeLiquidity(MarketParameters memory market, uint256 _lpToRemove)
        internal
        pure
        returns (uint256 _lytToAccount, uint256 _otToAccount)
    {
        int256 lpToRemove = _lpToRemove.Int();
        int256 lytToAccount;
        int256 otToAccount;

        require(lpToRemove > 0, "invalid lp amount");

        lytToAccount = (market.totalLp * market.totalOt) / market.totalLp;
        otToAccount = (market.totalLp * market.totalLyt) / market.totalLp;

        market.totalLp = market.totalLp.subNoNeg(lpToRemove);
        market.totalOt = market.totalOt.subNoNeg(otToAccount);
        market.totalLyt = market.totalLyt.subNoNeg(lytToAccount);

        _lytToAccount = lytToAccount.Uint();
        _otToAccount = otToAccount.Uint();
    }

    function calcExactOtForLyt(
        MarketParameters memory market,
        uint256 exactOtToMarket,
        uint256 timeToExpiry
    ) internal pure returns (uint256 netLytToAccount, uint256 netLytToReserve) {
        (int256 _netLytToAccount, int256 _netLytToReserve) = calcTrade(
            market,
            exactOtToMarket.neg(),
            timeToExpiry
        );
        netLytToAccount = _netLytToAccount.Uint();
        netLytToReserve = _netLytToReserve.Uint();
    }

    function calcLytForExactOt(
        MarketParameters memory market,
        uint256 exactOtToAccount,
        uint256 timeToExpiry
    ) internal pure returns (uint256 netLytToMarket, uint256 netLytToReserve) {
        (int256 _netLytToAccount, int256 _netLytToReserve) = calcTrade(
            market,
            exactOtToAccount.Int(),
            timeToExpiry
        );
        netLytToMarket = _netLytToAccount.neg().Uint();
        netLytToReserve = _netLytToReserve.Uint();
    }

    /// @notice Calculates the asset amount the results from trading otToAccount with the market. A positive
    /// otToAccount is equivalent of swapping OT into the market, a negative is taking OT out.
    /// Updates the market state in memory.
    /// @param market the current market state
    /// @param otToAccount the OT amount that will be deposited into the user's portfolio. The net change
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
        require(market.totalOt > otToAccount, "insufficient liquidity");

        // Calculates initial rate factors for the trade
        (int256 rateScalar, int256 totalAsset, int256 rateAnchor) = getExchangeRateFactors(
            market,
            timeToExpiry
        );

        // Calculates the exchange rate from Asset to OT before any liquidity fees
        // are applied
        int256 preFeeExchangeRate;
        {
            preFeeExchangeRate = getExchangeRate(
                market.totalOt,
                totalAsset,
                rateScalar,
                rateAnchor,
                otToAccount
            );
        }

        NetTo memory netAsset;
        // Given the exchange rate, returns the netAsset amounts to apply to each of the
        // three relevant balances.
        (
            netAsset.toAccount,
            netAsset.toMarket,
            netAsset.toReserve
        ) = _getNetAssetAmountsToAddresses(
            market.feeRateRoot,
            preFeeExchangeRate,
            otToAccount,
            timeToExpiry,
            market.reserveFeePercent
        );

        //////////////////////////////////
        /// Update params in the market///
        //////////////////////////////////
        {
            // Set the new implied interest rate after the trade has taken effect, this
            // will be used to calculate the next trader's interest rate.
            market.totalOt = market.totalOt.subNoNeg(otToAccount);
            market.lastImpliedRate = getImpliedRate(
                market.totalOt,
                totalAsset + netAsset.toMarket,
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
            netAsset.toAccount,
            netAsset.toMarket,
            netAsset.toReserve
        );
    }

    /// @notice Returns factors for calculating exchange rates
    /// @return rateScalar a value in rate precision that defines the slope of the line
    /// @return totalAsset the converted LYT to Asset for calculatin the exchange rates for the trade
    /// @return rateAnchor an offset from the x axis to maintain interest rate continuity over time
    function getExchangeRateFactors(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
        returns (
            int256 rateScalar,
            int256 totalAsset,
            int256 rateAnchor
        )
    {
        rateScalar = getRateScalar(market, timeToExpiry);
        totalAsset = LYTUtils.lytToAsset(market.lytRate, market.totalLyt);

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
        int256 fee = getExchangeRateFromImpliedRate(feeRateRoot, timeToExpiry);

        if (otToAccount > 0) {
            // swapping LYT for OT

            // Dividing reduces exchange rate, swapping LYT to OT means account should receive less OT
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(fee);
            // It's possible that the fee pushes exchange rates into negative territory. This is not possible
            // when swapping OT to LYT. If this happens then the trade has failed.
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
            // swapping OT for LYT

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
    /// @return netLytToAccount the positive or negative change in asset lyt to the account
    /// @return netLytToReserve the positive amount of lyt that accrues to the reserve
    function _setNewMarketState(
        MarketParameters memory market,
        int256 netAssetToAccount,
        int256 netAssetToMarket,
        int256 netAssetToReserve
    ) private pure returns (int256 netLytToAccount, int256 netLytToReserve) {
        int256 netLytToMarket = LYTUtils.assetToLyt(market.lytRate, netAssetToMarket);
        // Set storage checks that total asset lyt is above zero
        market.totalLyt = market.totalLyt + netLytToMarket;

        netLytToReserve = LYTUtils.assetToLyt(market.lytRate, netAssetToReserve);
        netLytToAccount = LYTUtils.assetToLyt(market.lytRate, netAssetToAccount);
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
    ) internal pure returns (int256 rateAnchor) {
        // This is the exchange rate at the new time to expiry
        int256 newExchangeRate = getExchangeRateFromImpliedRate(lastImpliedRate, timeToExpiry);

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
    function getImpliedRate(
        int256 totalOt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        uint256 timeToExpiry
    ) internal pure returns (uint256 impliedRate) {
        // This will check for exchange rates < FixedPoint.ONE_INT
        int256 exchangeRate = getExchangeRate(totalOt, totalAsset, rateScalar, rateAnchor, 0);

        // exchangeRate >= 1 so its ln >= 0
        uint256 lnRate = exchangeRate.ln().Uint();

        impliedRate = (lnRate * IMPLIED_RATE_TIME) / timeToExpiry;

        // Implied rates over 429% will overflow, this seems like a safe assumption
        // TODO: Probably this is not necessary
        require(impliedRate <= type(uint32).max);
    }

    /// @notice Converts an implied rate to an exchange rate given a time to expiry. The
    /// formula is E = e^rt
    function getExchangeRateFromImpliedRate(uint256 impliedRate, uint256 timeToExpiry)
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
    function getExchangeRate(
        int256 totalOt,
        int256 totalAsset,
        int256 rateScalar,
        int256 rateAnchor,
        int256 otToAccount
    ) internal pure returns (int256 exchangeRate) {
        int256 numerator = totalOt.subNoNeg(otToAccount);

        // This is the proportion scaled by FixedPoint.ONE_INT
        // (totalOt + otToMarket) / (totalOt + totalAsset)
        int256 proportion = (numerator.divDown(totalOt + totalAsset));

        // This limit is here to prevent the market from reaching extremely high interest rates via an
        // excessively large proportion (high amounts of OT relative to Asset).
        // Market proportion can only increase via swapping OT to LYT (OT is added to the market and LYT is
        // removed). Over time, the yield from LYT will slightly decrease the proportion (the
        // amount of Asset in the market must be monotonically increasing). Therefore it is not
        // possible for the proportion to go over max market proportion unless borrowing occurs.
        require(proportion <= MAX_MARKET_PROPORTION); // TODO: probably not applicable to Pendle

        int256 lnProportion = _logProportion(proportion);

        // lnProportion / rateScalar + rateAnchor
        exchangeRate = lnProportion.divDown(rateScalar) + rateAnchor;

        // Do not succeed if interest rates fall below 1
        require(exchangeRate >= FixedPoint.ONE_INT, "exchange rate below 1");
    }

    function _logProportion(int256 proportion) internal pure returns (int256 res) {
        // This will result in divide by zero, short circuit
        require(proportion != FixedPoint.ONE_INT);

        // Convert proportion to what is used inside the logit function (p / (1-p))
        int256 logitP = proportion.divDown(FixedPoint.ONE_INT - proportion);

        res = logitP.ln();
    }

    function getRateScalar(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
        returns (int256 rateScalar)
    {
        rateScalar = (market.scalarRoot * IMPLIED_RATE_TIME.Int()) / timeToExpiry.Int();
        require(rateScalar > 0, "rateScalar underflow");
    }

    function setInitialImpliedRate(MarketParameters memory market, uint256 timeToExpiry)
        internal
        pure
    {
        int256 totalAsset = LYTUtils.lytToAsset(market.lytRate, market.totalLyt);
        market.lastImpliedRate = getImpliedRate(
            market.totalOt,
            totalAsset,
            market.scalarRoot,
            market.anchorRoot,
            timeToExpiry
        );
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                    Utility functions                                    ////
    ////////////////////////////////////////////////////////////////////////////////////////////////

    function getTimeToExpiry(MarketParameters memory market) internal view returns (uint256) {
        unchecked {
            require(block.timestamp <= market.expiry, "market expired");
            return block.timestamp - market.expiry;
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

    //////////////////////////////////////////////////////////////////////////////////////
    ///                                Approx functions                                ///
    //////////////////////////////////////////////////////////////////////////////////////

    function approxSwapExactLytForOt(
        MarketParameters memory marketImmutable,
        uint256 exactLytIn,
        uint256 timeToExpiry,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) internal pure returns (uint256 netOtOut) {
        require(exactLytIn > 0, "invalid lyt in");
        require(
            netOtOutGuessMin >= 0 && netOtOutGuessMax >= 0 && netOtOutGuessMin <= netOtOutGuessMax,
            "invalid guess"
        );

        uint256 low = netOtOutGuessMin;
        uint256 high = netOtOutGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentOtOutGuess = (low + high + 1) / 2;
            MarketParameters memory market = deepCloneMarket(marketImmutable);

            (uint256 netLytNeed, ) = calcLytForExactOt(market, currentOtOutGuess, timeToExpiry);
            bool isResultAcceptable = (netLytNeed <= exactLytIn);
            if (isResultAcceptable) {
                low = currentOtOutGuess;
                isAcceptableAnswerExisted = true;
            } else high = currentOtOutGuess - 1;
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netOtOut = low;
    }

    function approxSwapOtForExactLyt(
        MarketParameters memory marketImmutable,
        uint256 exactLytOut,
        uint256 timeToExpiry,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax
    ) internal pure returns (uint256 netOtIn) {
        require(exactLytOut > 0, "invalid lyt in");
        require(
            netOtInGuessMin >= 0 && netOtInGuessMax >= 0 && netOtInGuessMin <= netOtInGuessMax,
            "invalid guess"
        );

        uint256 low = netOtInGuessMin;
        uint256 high = netOtInGuessMax;
        bool isAcceptableAnswerExisted;

        while (low != high) {
            uint256 currentOtInGuess = (low + high) / 2;
            MarketParameters memory market = deepCloneMarket(marketImmutable);

            (uint256 netLytToAccount, ) = calcExactOtForLyt(
                market,
                currentOtInGuess,
                timeToExpiry
            );
            bool isResultAcceptable = (netLytToAccount >= exactLytOut);
            if (isResultAcceptable) {
                high = currentOtInGuess;
                isAcceptableAnswerExisted = true;
            } else {
                low = currentOtInGuess + 1;
            }
        }

        require(isAcceptableAnswerExisted, "guess fail");
        netOtIn = high;
    }

    function approxSwapExactLytForYt(
        MarketParameters memory marketImmutable,
        uint256 exactLytIn,
        uint256 timeToExpiry,
        uint256 netYtOutGuessMin,
        uint256 netYtOutGuessMax
    ) internal pure returns (uint256 netYtOut) {
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
        netYtOut = low;
    }
}
