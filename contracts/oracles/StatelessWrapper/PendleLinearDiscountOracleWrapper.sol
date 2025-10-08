// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IPChainlinkOracleEssential} from "../../interfaces/IPChainlinkOracleEssential.sol";

/**
 * Oracle wrapper that updates the `updatedAt` field to the current block timestamp.
 * Intended to use with the Chainlink-compatible oracles that are stateless but with updatedAt field equal to 0.
 */
contract PendleLinearDiscountOracleWrapper is IPChainlinkOracleEssential {
    IPChainlinkOracleEssential public immutable innerOracle;

    constructor(address _innerOracle) {
        innerOracle = IPChainlinkOracleEssential(_innerOracle);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = innerOracle.latestRoundData();
        updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return innerOracle.decimals();
    }
}
