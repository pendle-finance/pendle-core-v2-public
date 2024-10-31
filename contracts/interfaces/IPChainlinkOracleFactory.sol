// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPChainlinkOracle.sol";

interface IPChainlinkOracleFactory {
    event SetPyLpOracle(address newPyLpOracle);

    event OracleCreated(
        address indexed market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType,
        address indexed oracle
    );
    event OracleWithQuoteCreated(
        address indexed market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType,
        address indexed quoteOracle,
        address indexed oracle
    );

    function pyLpOracle() external view returns (address);
}
