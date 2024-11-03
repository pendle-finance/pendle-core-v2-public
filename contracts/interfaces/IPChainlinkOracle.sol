// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

enum PendleOraclePricingType {
    TO_SY,
    TO_UNDERLYING
}

enum PendleOracleTokenType {
    PT,
    YT,
    LP
}

interface IPChainlinkOracle is AggregatorV3Interface {}
