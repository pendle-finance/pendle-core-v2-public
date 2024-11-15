// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../interfaces/IPChainlinkOracle.sol";
import "../PendleLpOracleLib.sol";

/**
 * @dev The round data returned from this contract will follow:
 * - There will be only one round (roundId=0)
 * - startedAt=0, updatedAt=block.timestamp
 */
abstract contract PendleChainlinkOracleBase is IPChainlinkOracle {
    using PendlePYOracleLib for IPMarket;
    using PendleLpOracleLib for IPMarket;

    error InvalidRoundId();

    // solhint-disable immutable-vars-naming
    address public immutable factory;
    address public immutable market;
    uint16 public immutable twapDuration;

    uint8 public immutable fromTokenDecimals;
    uint8 public immutable toTokenDecimals;

    PendleOracleType public immutable baseOracleType;

    modifier validateRoundId(uint80 roundId) {
        if (roundId != 0) {
            revert InvalidRoundId();
        }
        _;
    }

    constructor(address _market, uint16 _twapDuration, PendleOracleType _baseOracleType) {
        factory = msg.sender;
        market = _market;
        twapDuration = _twapDuration;
        baseOracleType = _baseOracleType;
        (fromTokenDecimals, toTokenDecimals) = _readDecimals(_market, _baseOracleType);
    }

    // =================================================================
    //                          CHAINLINK INTERFACE
    // =================================================================

    function latestRoundData()
        public
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 0;
        answer = _getFinalPrice();
        startedAt = 0;
        updatedAt = block.timestamp;
        answeredInRound = 0;
    }

    function getRoundData(
        uint80 roundId
    ) external view validateRoundId(roundId) returns (uint80, int256, uint256, uint256, uint80) {
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

    function _getFinalPrice() internal view virtual returns (int256);

    function _getPendleTokenPrice() internal view returns (int256) {
        if (baseOracleType == PendleOracleType.PT_TO_SY) {
            return _unscalePrice(IPMarket(market).getPtToSyRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.PT_TO_ASSET) {
            return _unscalePrice(IPMarket(market).getPtToAssetRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.YT_TO_SY) {
            return _unscalePrice(IPMarket(market).getYtToSyRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.YT_TO_ASSET) {
            return _unscalePrice(IPMarket(market).getYtToAssetRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.LP_TO_SY) {
            return _unscalePrice(IPMarket(market).getLpToSyRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.LP_TO_ASSET) {
            return _unscalePrice(IPMarket(market).getLpToAssetRate(twapDuration));
        } else {
            revert("not supported");
        }
    }

    function _unscalePrice(uint256 price) internal view returns (int256 unwrappedPrice) {
        unwrappedPrice = PMath.Int((price * (10 ** fromTokenDecimals)) / (10 ** toTokenDecimals));
    }

    function _readDecimals(
        address _market,
        PendleOracleType _oracleType
    ) internal view returns (uint8 _fromDecimals, uint8 _toDecimals) {
        (IStandardizedYield SY, , ) = IPMarket(_market).readTokens();

        uint8 lpDecimals = 18;
        uint8 syDecimals = SY.decimals();
        (, , uint8 assetDecimals) = SY.assetInfo();

        if (_oracleType == PendleOracleType.LP_TO_ASSET) {
            _fromDecimals = lpDecimals;
            _toDecimals = assetDecimals;
        } else if (_oracleType == PendleOracleType.LP_TO_SY) {
            _fromDecimals = lpDecimals;
            _toDecimals = syDecimals;
        } else if (_oracleType == PendleOracleType.PT_TO_ASSET || _oracleType == PendleOracleType.YT_TO_ASSET) {
            _fromDecimals = assetDecimals;
            _toDecimals = assetDecimals;
        } else if (_oracleType == PendleOracleType.PT_TO_SY || _oracleType == PendleOracleType.YT_TO_SY) {
            _fromDecimals = assetDecimals;
            _toDecimals = syDecimals;
        }
    }
}
