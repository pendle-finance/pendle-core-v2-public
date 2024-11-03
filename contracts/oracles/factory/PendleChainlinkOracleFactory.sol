// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracle.sol";
import "./PendleChainlinkOracleWithQuote.sol";
import "../../interfaces/IPChainlinkOracleFactory.sol";
import "../../interfaces/IPPYLpOracle.sol";

contract PendleChainlinkOracleFactory is IPChainlinkOracleFactory {
    error OracleAlreadyExists();
    error OracleNotReady();

    // [keccak256(market, duration, pricingType, pricingToken)]
    mapping(bytes32 oracleId => address oracleAddr) public oracles;

    // [keccak256(market, duration, pricingType, pricingToken, quoteOracle)]
    mapping(bytes32 oracleId => address oracleAddr) public oraclesWithQuote;

    address public immutable pyLpOracle;

    constructor(address _pyLpOracle) {
        pyLpOracle = _pyLpOracle;
    }

    function createOracle(
        address market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType
    ) external returns (address oracle) {
        bytes32 oracleId = getOracleId(market, twapDuration, pricingType, tokenType);
        if (oracles[oracleId] != address(0)) revert OracleAlreadyExists();

        _checkOracleState(market, twapDuration);

        oracle = address(new PendleChainlinkOracle(market, twapDuration, pricingType, tokenType));
        oracles[oracleId] = oracle;
        emit OracleCreated(market, twapDuration, pricingType, tokenType, oracle, oracleId);
    }

    function createOracleWithQuote(
        address market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType,
        address quoteOracle
    ) external returns (address oracle) {
        bytes32 oracleId = getOracleWithQuoteId(market, twapDuration, pricingType, tokenType, quoteOracle);
        if (oraclesWithQuote[oracleId] != address(0)) revert OracleAlreadyExists();

        _checkOracleState(market, twapDuration);

        oracle = address(new PendleChainlinkOracleWithQuote(market, twapDuration, pricingType, tokenType, quoteOracle));
        oraclesWithQuote[oracleId] = oracle;
        emit OracleWithQuoteCreated(market, twapDuration, pricingType, tokenType, quoteOracle, oracle, oracleId);
    }

    function getOracleId(
        address market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(market, twapDuration, pricingType, tokenType));
    }

    function getOracleWithQuoteId(
        address market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType,
        address quoteOracle
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(market, twapDuration, pricingType, tokenType, quoteOracle));
    }

    function _checkOracleState(address market, uint16 twapDuration) internal view {
        (bool increaseCardinalityRequired, , bool oldestObservationSatisfied) = IPPYLpOracle(pyLpOracle).getOracleState(
            market,
            twapDuration
        );
        if (!increaseCardinalityRequired && oldestObservationSatisfied) {
            revert OracleNotReady();
        }
    }
}
