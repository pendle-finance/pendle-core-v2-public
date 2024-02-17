// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../core/libraries/math/PMath.sol";
import "../interfaces/IPExchangeRateOracle.sol";
import "../interfaces/IRedstonePriceFeed.sol";

contract PendleRedStoneRateOracleAdapter is IPExchangeRateOracle {
    using PMath for int256;

    address public immutable oracle;
    uint8 public immutable decimals;
    uint8 public immutable rawDecimals;

    constructor(address _redStoneOracle, uint8 _decimals) {
        oracle = _redStoneOracle;
        decimals = _decimals;
        rawDecimals = IRedstonePriceFeed(_redStoneOracle).decimals();
    }

    function getExchangeRate() external view returns (uint256) {
        int256 answer = IRedstonePriceFeed(oracle).latestAnswer();
        return (answer.Uint() * 10 ** decimals) / 10 ** rawDecimals;
    }
}
