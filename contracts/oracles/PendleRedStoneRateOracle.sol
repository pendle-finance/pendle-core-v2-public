// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../core/libraries/math/PMath.sol";
import "../interfaces/IPExchangeRateOracle.sol";
import {AggregatorV3Interface as IChainlinkAggregator} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract PendleRedStoneRateOracle is IPExchangeRateOracle {
    using PMath for int256;

    address public immutable oracle;
    uint8 public immutable decimals;

    constructor(address _redStoneOracle, uint8 _decimals) {
        oracle = _redStoneOracle;
        decimals = _decimals;
    }

    function getExchangeRate() external view returns (uint256) {
        (, int256 answer, , , ) = IChainlinkAggregator(oracle).latestRoundData();
        return (answer.Uint() * 10 ** decimals) / 10 ** IChainlinkAggregator(oracle).decimals();
    }
}
