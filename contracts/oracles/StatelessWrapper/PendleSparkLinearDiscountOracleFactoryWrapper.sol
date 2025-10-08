// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {PendleLinearDiscountOracleWrapper} from "./PendleLinearDiscountOracleWrapper.sol";
import {PendleSparkLinearDiscountOracleFactory} from "../internal/PendleSparkLinearDiscountOracleFactory.sol";

contract PendleSparkLinearDiscountOracleFactoryWrapper {
    event WrapperOracleCreated(address indexed innerOracle, address indexed wrapper);

    PendleSparkLinearDiscountOracleFactory public immutable innerFactory;

    constructor(address _innerFactory) {
        innerFactory = PendleSparkLinearDiscountOracleFactory(_innerFactory);
    }

    function wrap(address innerOracle) public returns (address wrapper) {
        wrapper = address(new PendleLinearDiscountOracleWrapper(innerOracle));
        emit WrapperOracleCreated(innerOracle, wrapper);
    }

    function createWithPt(address pt, uint256 baseDiscountPerYear) external returns (address wrapper) {
        address innerOracle = innerFactory.createWithPt(pt, baseDiscountPerYear);
        return wrap(innerOracle);
    }

    function createWithMarket(address market, uint256 baseDiscountPerYear) external returns (address wrapper) {
        address innerOracle = innerFactory.createWithMarket(market, baseDiscountPerYear);
        return wrap(innerOracle);
    }
}
