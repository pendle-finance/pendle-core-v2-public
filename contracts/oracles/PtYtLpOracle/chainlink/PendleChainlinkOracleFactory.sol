// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracle.sol";
import "./PendleChainlinkOracleWithQuote.sol";
import "../../../interfaces/IPChainlinkOracleFactory.sol";
import "../../../interfaces/IPPYLpOracle.sol";

contract PendleChainlinkOracleFactory is IPChainlinkOracleFactory {
    error OracleAlreadyExists();

    error OracleIncreaseCardinalityRequired(uint32 cardinalityRequired);
    error OracleOldestObservationNotSatisfied();

    // [keccak256(market, duration, baseOracleType)]
    mapping(bytes32 oracleId => address oracleAddr) internal oracles;

    // [keccak256(market, duration, baseOracleType, quoteOracle)]
    mapping(bytes32 oracleId => address oracleAddr) internal oraclesWithQuote;

    address public immutable pyLpOracle;

    constructor(address _pyLpOracle) {
        pyLpOracle = _pyLpOracle;
    }

    // =================================================================
    //                          CREATE ORACLE
    // =================================================================

    function createOracle(
        address market,
        uint32 twapDuration,
        PendleOracleType baseOracleType
    ) external returns (address oracle) {
        bytes32 oracleId = getOracleId(market, twapDuration, baseOracleType);
        if (oracles[oracleId] != address(0)) revert OracleAlreadyExists();

        checkMarketOracleState(market, twapDuration);

        oracle = address(new PendleChainlinkOracle(market, twapDuration, baseOracleType));
        oracles[oracleId] = oracle;
        emit OracleCreated(market, twapDuration, baseOracleType, oracle, oracleId);
    }

    /**
     * @dev quoteOracle must has Chainlink-compatible interface
     */
    function createOracleWithQuote(
        address market,
        uint32 twapDuration,
        PendleOracleType baseOracleType,
        address quoteOracle
    ) external returns (address oracle) {
        bytes32 oracleId = getOracleWithQuoteId(market, twapDuration, baseOracleType, quoteOracle);
        if (oraclesWithQuote[oracleId] != address(0)) revert OracleAlreadyExists();

        checkMarketOracleState(market, twapDuration);

        oracle = address(new PendleChainlinkOracleWithQuote(market, twapDuration, baseOracleType, quoteOracle));
        oraclesWithQuote[oracleId] = oracle;
        emit OracleWithQuoteCreated(market, twapDuration, baseOracleType, quoteOracle, oracle, oracleId);
    }

    // =================================================================
    //                          GET ORACLE
    // =================================================================

    function getOracle(
        address market,
        uint32 twapDuration,
        PendleOracleType baseOracleType
    ) public view returns (address) {
        return oracles[getOracleId(market, twapDuration, baseOracleType)];
    }

    function getOracleWithQuote(
        address market,
        uint32 twapDuration,
        PendleOracleType baseOracleType,
        address quoteOracle
    ) public view returns (address) {
        return oraclesWithQuote[getOracleWithQuoteId(market, twapDuration, baseOracleType, quoteOracle)];
    }

    function getOracleId(
        address market,
        uint32 twapDuration,
        PendleOracleType baseOracleType
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(market, twapDuration, baseOracleType));
    }

    function getOracleWithQuoteId(
        address market,
        uint32 twapDuration,
        PendleOracleType baseOracleType,
        address quoteOracle
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(market, twapDuration, baseOracleType, quoteOracle));
    }

    // =================================================================
    //                          CHECK ORACLE STATE
    // =================================================================

    function checkMarketOracleState(address market, uint32 twapDuration) public view {
        (bool increaseCardinalityRequired, uint32 cardinalityRequired, bool oldestObservationSatisfied) = IPPYLpOracle(
            pyLpOracle
        ).getOracleState(market, twapDuration);

        if (increaseCardinalityRequired) {
            // call IPMarket(market).increaseObservationsCardinalityNext(cardinalityRequired) then wait for twapDuration seconds
            revert OracleIncreaseCardinalityRequired(cardinalityRequired);
        }
        if (!oldestObservationSatisfied) {
            // wait for twapDuration seconds
            revert OracleOldestObservationNotSatisfied();
        }
    }
}
