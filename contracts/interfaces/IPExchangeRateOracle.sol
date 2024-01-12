// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPExchangeRateOracle {
    function getExchangeRate() external view returns (uint256);
}
