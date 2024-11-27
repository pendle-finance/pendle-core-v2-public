// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

interface IPChainlinkOracleWithQuote is AggregatorV2V3Interface {
    function quoteOracle() external view returns (address);
}
