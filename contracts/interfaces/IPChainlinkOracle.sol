// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

enum PendleOracleType {
    PT_TO_SY,
    PT_TO_ASSET
}

interface IPChainlinkOracle is AggregatorV3Interface {}
