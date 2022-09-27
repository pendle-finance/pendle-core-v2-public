// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/// Adapted from UniswapV3's Oracle

library Errors {
    error MarketExpired();
    error MarketZeroAmountsInput();
    error MarketZeroAmountsOutput();
    error MarketZeroLnImpliedRate();
    error MarketInsufficientLiquidity();

    error MarketInsufficientPT(uint256 actualBalance, uint256 requiredBalance);
    error MarketInsufficientSCY(uint256 actualBalance, uint256 requiredBalance);

    error MarketInvalidState(int256 totalPt, int256 totalAsset);
    error MarketExchangeRateBelowOne(int256 exchangeRate);
    error MarketProportionMustNotEqualOne();
    error MarketProportionTooHigh(int256 proportion);
    error MarketRateScalarTooLow(int256 rateScalar);
    error MarketScalarRootTooLow(int256 scalarRoot);
}
