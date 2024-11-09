// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../interfaces/IPChainlinkOracle.sol";
import "../PendleLpOracleLib.sol";

/**
 * @dev The round data returned from this contract will follow:
 * - There will be only one round (roundId=0)
 * - startedAt, updatedAt will always be block.timestamp
 */
abstract contract PendleChainlinkOracleBase is IPChainlinkOracle {
    using PendlePYOracleLib for IPMarket;
    using PendleLpOracleLib for IPMarket;

    error InvalidRoundId();

    // solhint-disable immutable-vars-naming
    address public immutable factory;
    address public immutable market;
    uint16 public immutable twapDuration;

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
    }

    // =================================================================
    //                          CHAINLINK INTERFACE
    // =================================================================

    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 0;
        answer = _getFinalPrice();
        startedAt = block.timestamp;
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
            return int256(IPMarket(market).getPtToSyRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.PT_TO_ASSET) {
            return int256(IPMarket(market).getPtToAssetRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.YT_TO_SY) {
            return int256(IPMarket(market).getYtToSyRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.YT_TO_ASSET) {
            return int256(IPMarket(market).getYtToAssetRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.LP_TO_SY) {
            return int256(IPMarket(market).getLpToSyRate(twapDuration));
        } else if (baseOracleType == PendleOracleType.LP_TO_ASSET) {
            return int256(IPMarket(market).getLpToAssetRate(twapDuration));
        } else {
            revert("not supported");
        }
    }
}
