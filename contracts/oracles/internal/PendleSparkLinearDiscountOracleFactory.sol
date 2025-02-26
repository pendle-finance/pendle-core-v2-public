// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {PendleSparkLinearDiscountOracle} from "./PendleSparkLinearDiscountOracle.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../../interfaces/IPMarket.sol";

contract PendleSparkLinearDiscountOracleFactory {
    function createWithPt(address pt, uint256 baseDiscountPerYear) external returns (address) {
        return address(new PendleSparkLinearDiscountOracle(pt, baseDiscountPerYear));
    }

    function createWithMarket(address market, uint256 baseDiscountPerYear) external returns (address) {
        (, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
        return address(new PendleSparkLinearDiscountOracle(address(PT), baseDiscountPerYear));
    }
}
