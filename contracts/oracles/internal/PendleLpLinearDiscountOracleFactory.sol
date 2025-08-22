// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {PendleLpLinearDiscountOracle} from "./PendleLpLinearDiscountOracle.sol";

contract PendleLpLinearDiscountOracleFactory {
    event OracleCreated(address indexed market, uint256 basePtDiscountPerYear, uint256 lpBasePrice, address oracle);

    /**
     * @notice Creates a new LP linear discount oracle
     * @param market The Pendle Market address (LP token)
     * @param basePtDiscountPerYear Annual discount rate for PT (max: 1e18 = 100%)
     * @param lpBasePrice Base price multiplier for LP (min: 1e18 = 1x)
     * @return res The address of the deployed oracle contract
     */
    function create(address market, uint256 basePtDiscountPerYear, uint256 lpBasePrice) external returns (address res) {
        res = address(new PendleLpLinearDiscountOracle(market, basePtDiscountPerYear, lpBasePrice));
        emit OracleCreated(market, basePtDiscountPerYear, lpBasePrice, res);
    }
}
