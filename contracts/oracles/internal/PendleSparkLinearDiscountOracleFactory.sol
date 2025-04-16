// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {PendleSparkLinearDiscountOracle} from "./PendleSparkLinearDiscountOracle.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPMarket.sol";

contract PendleSparkLinearDiscountOracleFactory {
    event OracleCreated(address indexed pt, uint256 baseDiscountPerYear, address oracle);

    function createWithPt(address pt, uint256 baseDiscountPerYear) external returns (address res) {
        res = address(new PendleSparkLinearDiscountOracle(pt, baseDiscountPerYear));
        emit OracleCreated(pt, baseDiscountPerYear, res);
    }

    function createWithMarket(address market, uint256 baseDiscountPerYear) external returns (address) {
        (, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        address res = address(new PendleSparkLinearDiscountOracle(address(PT), baseDiscountPerYear));
        emit OracleCreated(address(PT), baseDiscountPerYear, res);
        return res;
    }
}
