// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./PendleCornBaseSY.sol";

contract PendleCornLBTCSY is PendleCornBaseSY {
    // solhint-disable immutable-vars-naming
    // solhint-disable const-name-snakecase
    address public constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    constructor(
        address _initialExchangeRateOracle
    ) PendleCornBaseSY("SY Corn Lombard LBTC", "SY-cornLBTC", LBTC, WBTC, _initialExchangeRateOracle) {}
}
