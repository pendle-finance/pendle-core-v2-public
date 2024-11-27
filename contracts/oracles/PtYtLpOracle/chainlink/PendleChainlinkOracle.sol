// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../interfaces/IPChainlinkOracle.sol";
import "../PendleLpOracleLib.sol";

/**
 * @dev The round data returned from this contract will follow:
 * - There will be only one round (roundId=0)
 * - startedAt=0, updatedAt=block.timestamp
 */
contract PendleChainlinkOracle is IPChainlinkOracle {
    error InvalidRoundId();

    // solhint-disable immutable-vars-naming
    address public immutable factory;

    address public immutable market;
    uint32 public immutable twapDuration;
    PendleOracleType public immutable baseOracleType;

    uint256 public immutable fromTokenScale;
    uint256 public immutable toTokenScale;

    function(IPMarket, uint32) internal view returns (uint256) private immutable _getRawPendlePrice;

    modifier roundIdIsZero(uint80 roundId) {
        if (roundId != 0) {
            revert InvalidRoundId();
        }
        _;
    }

    constructor(address _market, uint32 _twapDuration, PendleOracleType _baseOracleType) {
        factory = msg.sender;
        market = _market;
        twapDuration = _twapDuration;
        baseOracleType = _baseOracleType;
        (uint256 fromTokenDecimals, uint256 toTokenDecimals) = _readDecimals(_market, _baseOracleType);
        (fromTokenScale, toTokenScale) = (10 ** fromTokenDecimals, 10 ** toTokenDecimals);
        _getRawPendlePrice = _getRawPendlePriceFunc();
    }

    // =================================================================
    //                          CHAINLINK INTERFACE
    // =================================================================

    /**
     * @notice The round data returned from this contract will follow:
     * - answer will satisfy 1 natural unit of PendleToken = (answer/1e18) natural unit of OutputToken
     * - In other words, 10**(PendleToken.decimals) = (answer/1e18) * 10**(OutputToken.decimals)
     * @param roundId always 0 for this contract
     * @param answer The answer (in 18 decimals)
     * @param startedAt always 0 for this contract
     * @param updatedAt always block.timestamp for this contract
     * @param answeredInRound always 0 for this contract
     */
    function latestRoundData()
        public
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 0;
        answer = _getPendleTokenPrice();
        startedAt = 0;
        updatedAt = block.timestamp;
        answeredInRound = 0;
    }

    function getRoundData(
        uint80 roundId
    ) external view roundIdIsZero(roundId) returns (uint80, int256, uint256, uint256, uint80) {
        return latestRoundData();
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function description() external pure returns (string memory) {
        return "Pendle Chainlink-compatible Oracle";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    // =================================================================
    //                          PRICING FUNCTIONS
    // =================================================================

    function _getPendleTokenPrice() internal view returns (int256) {
        return _descalePrice(_getRawPendlePrice(IPMarket(market), twapDuration));
    }

    function _descalePrice(uint256 price) private view returns (int256 unwrappedPrice) {
        return PMath.Int((price * fromTokenScale) / toTokenScale);
    }

    // =================================================================
    //                          USE ONLY AT INITIALIZATION
    // =================================================================

    function _getRawPendlePriceFunc()
        internal
        view
        returns (function(IPMarket, uint32) internal view returns (uint256))
    {
        if (baseOracleType == PendleOracleType.PT_TO_SY) {
            return PendlePYOracleLib.getPtToSyRate;
        } else if (baseOracleType == PendleOracleType.PT_TO_ASSET) {
            return PendlePYOracleLib.getPtToAssetRate;
        } else {
            revert("not supported");
        }
    }

    function _readDecimals(
        address _market,
        PendleOracleType _oracleType
    ) internal view returns (uint8 _fromDecimals, uint8 _toDecimals) {
        (IStandardizedYield SY, , ) = IPMarket(_market).readTokens();

        uint8 syDecimals = SY.decimals();
        (, , uint8 assetDecimals) = SY.assetInfo();

        if (_oracleType == PendleOracleType.PT_TO_ASSET) {
            return (assetDecimals, assetDecimals);
        } else if (_oracleType == PendleOracleType.PT_TO_SY) {
            return (assetDecimals, syDecimals);
        }
    }
}
