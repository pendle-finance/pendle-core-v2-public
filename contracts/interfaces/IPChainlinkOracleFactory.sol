// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPChainlinkOracle.sol";

interface IPChainlinkOracleFactory {
    event OracleCreated(
        address indexed market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType,
        address indexed oracle,
        bytes32 oracleId
    );
    event OracleWithQuoteCreated(
        address indexed market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType,
        address indexed quoteOracle,
        address indexed oracle,
        bytes32 oracleId
    );
}
