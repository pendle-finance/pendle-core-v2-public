// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracle.sol";
import "./PendleChainlinkOracleWithQuote.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";

contract PendleChainlinkOracleFactory is IPChainlinkOracleFactory, BoringOwnableUpgradeable {
    error OracleAlreadyExists();

    // [market, uint256(duration, pricingType, pricingToken)]
    mapping(address => mapping(uint256 => address)) public oracles;

    // [market, uint256(duration, pricingType, pricingToken), quoteOracle]
    mapping(address => mapping(uint256 => mapping(address => address))) public oraclesWithQuote;

    address public pyLpOracle;

    constructor(address _pyLpOracle) initializer {
        _setPyLpOracle(_pyLpOracle);
        __BoringOwnable_init();
    }

    function createOracle(
        address market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType
    ) external returns (address oracle) {
        uint256 oracleType = _encodeOracleType(twapDuration, pricingType, tokenType);
        if (oracles[market][oracleType] != address(0)) revert OracleAlreadyExists();

        oracle = Create2.deploy(
            0,
            bytes32(0),
            abi.encodePacked(
                type(PendleChainlinkOracle).creationCode,
                abi.encode(market, twapDuration, pricingType, tokenType)
            )
        );
        oracles[market][oracleType] = oracle;
        emit OracleCreated(market, twapDuration, pricingType, tokenType, oracle);
    }

    function createOracleWithQuote(
        address market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType,
        address quoteOracle
    ) external returns (address oracle) {
        uint256 oracleType = _encodeOracleType(twapDuration, pricingType, tokenType);
        if (oraclesWithQuote[market][oracleType][quoteOracle] != address(0)) revert OracleAlreadyExists();

        oracle = Create2.deploy(
            0,
            bytes32(0),
            abi.encodePacked(
                type(PendleChainlinkOracleWithQuote).creationCode,
                abi.encode(market, twapDuration, pricingType, tokenType, quoteOracle)
            )
        );
        oraclesWithQuote[market][oracleType][quoteOracle] = oracle;
        emit OracleWithQuoteCreated(market, twapDuration, pricingType, tokenType, quoteOracle, oracle);
    }

    function getOracle(
        address market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType
    ) public view returns (address) {
        return oracles[market][_encodeOracleType(twapDuration, pricingType, tokenType)];
    }

    function getOracleWithQuote(
        address market,
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType,
        address quoteOracle
    ) public view returns (address) {
        return oraclesWithQuote[market][_encodeOracleType(twapDuration, pricingType, tokenType)][quoteOracle];
    }

    function _encodeOracleType(
        uint16 twapDuration,
        PendleOraclePricingType pricingType,
        PendleOracleTokenType tokenType
    ) internal pure returns (uint256 oracleType) {
        oracleType = twapDuration;
        oracleType = (oracleType << 1) | uint256(pricingType);
        oracleType = (oracleType << 2) | uint256(tokenType);
    }

    function _decodeOracleType(
        uint256 oracleType
    )
        internal
        pure
        returns (uint16 twapDuration, PendleOraclePricingType pricingType, PendleOracleTokenType tokenType)
    {
        tokenType = PendleOracleTokenType(oracleType & 3);
        pricingType = PendleOraclePricingType((oracleType >> 2) & 1);
        twapDuration = uint16(oracleType >> 3);
    }

    // =================================================================
    //                          ADMIN-FUNCTIONS
    // =================================================================

    function setPyLpOracle(address _pyLpOracle) external onlyOwner {
        _setPyLpOracle(_pyLpOracle);
    }

    function _setPyLpOracle(address _pyLpOracle) internal {
        pyLpOracle = _pyLpOracle;
        emit SetPyLpOracle(_pyLpOracle);
    }

}
