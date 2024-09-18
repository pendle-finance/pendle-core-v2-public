// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../core/libraries/math/PMath.sol";
import "../interfaces/IPExchangeRateOracle.sol";

contract PendleBoringSolvBTCOneracle is IPExchangeRateOracle {
    function getExchangeRate() external pure returns (uint256) {
        return 10 ** 8;
    }
}
