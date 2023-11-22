// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../interfaces/IPPtOracle.sol";
import "../../core/libraries/math/PMath.sol";
import {AggregatorV2V3Interface as IChainlinkAggregator} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

/**
 * @notice The returned price from this contract is multiply with the default USD price of asset
 * read from Chainlink Oracles
 *
 * @dev The ptRate is fetched from PendlePtOracle contract
 */
contract PendlePtUsdChainlinkOracle {
    address public immutable ptOracle;
    uint32 public immutable twapDuration;
    address public immutable market;
    address public immutable feed;
    uint8 public immutable feedDecimals;

    error OracleNotReady(bool increaseCardinalityRequired, bool oldestObservationSatisfied);

    constructor(address _ptOracle, uint32 _twapDuration, address _market, address _feed) {
        ptOracle = _ptOracle;
        twapDuration = _twapDuration;
        market = _market;
        feed = _feed;
        feedDecimals = IChainlinkAggregator(feed).decimals();

        (bool increaseCardinalityRequired, , bool oldestObservationSatisfied) = IPPtOracle(_ptOracle).getOracleState(
            market,
            twapDuration
        );

        if (increaseCardinalityRequired || !oldestObservationSatisfied) {
            revert OracleNotReady(increaseCardinalityRequired, oldestObservationSatisfied);
        }
    }

    function getPtPrice() external view virtual returns (uint256) {
        uint256 ptRate = IPPtOracle(ptOracle).getPtToAssetRate(market, twapDuration);
        uint256 assetPrice = _getUnderlyingAssetPrice();
        return (assetPrice * ptRate) / PMath.ONE;
    }

    function _getUnderlyingAssetPrice() internal view virtual returns (uint256) {
        uint256 rawPrice = uint256(IChainlinkAggregator(feed).latestAnswer());
        return feedDecimals < 18 ? rawPrice * 10 ** (18 - feedDecimals) : rawPrice / 10 ** (feedDecimals - 18);
    }

    function decimals() external pure virtual returns (uint8) {
        return 18;
    }
}
