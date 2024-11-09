// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracle.sol";
import "./PendleChainlinkOracleWithQuote.sol";
import "../../interfaces/IPChainlinkOracleFactory.sol";
import "../../interfaces/IPPYLpOracle.sol";

contract PendleChainlinkOracleFactory is IPChainlinkOracleFactory {
    error OracleAlreadyExists();
    error OracleNotReady();

    // [keccak256(market, duration, baseOracleType)]
    mapping(bytes32 oracleId => address oracleAddr) public oracles;

    // [keccak256(market, duration, baseOracleType, quoteOracle)]
    mapping(bytes32 oracleId => address oracleAddr) public oraclesWithQuote;

    address public immutable pyLpOracle;

    constructor(address _pyLpOracle) {
        pyLpOracle = _pyLpOracle;
    }

    function createOracle(
        address market,
        uint16 twapDuration,
        PendleOracleType baseOracleType
    ) external returns (address oracle) {
        bytes32 oracleId = _getOracleId(market, twapDuration, baseOracleType);
        if (oracles[oracleId] != address(0)) revert OracleAlreadyExists();

        _checkOracleState(market, twapDuration);

        oracle = address(new PendleChainlinkOracle(market, twapDuration, baseOracleType));
        oracles[oracleId] = oracle;
        emit OracleCreated(market, twapDuration, baseOracleType, oracle, oracleId);
    }

    function createOracleWithQuote(
        address market,
        uint16 twapDuration,
        PendleOracleType baseOracleType,
        address quoteOracle
    ) external returns (address oracle) {
        bytes32 oracleId = _getOracleWithQuoteId(market, twapDuration, baseOracleType, quoteOracle);
        if (oraclesWithQuote[oracleId] != address(0)) revert OracleAlreadyExists();

        _checkOracleState(market, twapDuration);

        oracle = address(new PendleChainlinkOracleWithQuote(market, twapDuration, baseOracleType, quoteOracle));
        oraclesWithQuote[oracleId] = oracle;
        emit OracleWithQuoteCreated(market, twapDuration, baseOracleType, quoteOracle, oracle, oracleId);
    }

    function getOracle(
        address market,
        uint16 twapDuration,
        PendleOracleType baseOracleType
    ) public view returns (address) {
        return oracles[_getOracleId(market, twapDuration, baseOracleType)];
    }

    function getOracleWithQuote(
        address market,
        uint16 twapDuration,
        PendleOracleType baseOracleType,
        address quoteOracle
    ) public view returns (address) {
        return oraclesWithQuote[_getOracleWithQuoteId(market, twapDuration, baseOracleType, quoteOracle)];
    }

    function _getOracleId(
        address market,
        uint16 twapDuration,
        PendleOracleType baseOracleType
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(market, twapDuration, baseOracleType));
    }

    function _getOracleWithQuoteId(
        address market,
        uint16 twapDuration,
        PendleOracleType baseOracleType,
        address quoteOracle
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(market, twapDuration, baseOracleType, quoteOracle));
    }

    function _checkOracleState(address market, uint16 twapDuration) internal view {
        (bool increaseCardinalityRequired, , bool oldestObservationSatisfied) = IPPYLpOracle(pyLpOracle).getOracleState(
            market,
            twapDuration
        );
        if (increaseCardinalityRequired || !oldestObservationSatisfied) {
            revert OracleNotReady();
        }
    }
}
