// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPChainlinkOracle.sol";

interface IPChainlinkOracleFactory {
    event OracleCreated(
        address indexed market,
        uint32 indexed twapDuration,
        PendleOracleType indexed baseOracleType,
        address oracle,
        bytes32 oracleId
    );
    event OracleWithQuoteCreated(
        address indexed market,
        uint32 indexed twapDuration,
        PendleOracleType indexed baseOracleType,
        address quoteOracle,
        address oracle,
        bytes32 oracleId
    );
}
