// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {PendleSparkLinearDiscountOracle} from "./PendleSparkLinearDiscountOracle.sol";

contract PendleSparkLinearDiscountOracleFactory {
    function create(address _pt, uint256 _baseDiscountPerYear) external returns (address) {
        return address(new PendleSparkLinearDiscountOracle(_pt, _baseDiscountPerYear));
    }
}
