// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPExchangeRateOracle} from "../../../interfaces/IPExchangeRateOracle.sol";
import {IPExchangeRateOracleApp} from "../../../interfaces/IPExchangeRateOracleApp.sol";

contract PendleExchangeRateOracleV2 is IPExchangeRateOracle {
    address public immutable exchangeRateOracleApp;
    uint32 public immutable srcEid;
    bytes32 public immutable exchangeRateSource;

    constructor(address _exchangeRateOracleApp, uint32 _srcEid, bytes32 _exchangeRateSource) {
        exchangeRateOracleApp = _exchangeRateOracleApp;
        srcEid = _srcEid;
        exchangeRateSource = _exchangeRateSource;
    }

    function getExchangeRate() external view returns (uint256) {
        IPExchangeRateOracleApp.ExchangeRateData memory exchangeRateData =
            IPExchangeRateOracleApp(exchangeRateOracleApp).getExchangeRate(srcEid, exchangeRateSource);

        return exchangeRateData.exchangeRate;
    }
}
