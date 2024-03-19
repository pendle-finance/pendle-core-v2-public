// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../interfaces/IPPtLpOracle.sol";
import "../../interfaces/IPMarket.sol";
import "../../core/libraries/math/PMath.sol";
import "../PendleLpOracleLib.sol";

import {AggregatorV2V3Interface as IChainlinkAggregator} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

/**
 * @notice The returned price from this contract is multiplied by the default USD price of the asset, as read from Chainlink Oracles.
 * For more details into how the oracle is implemented, refer to PendlePtOracle & PendlePtOracleLib.
 */
contract BoringPtUsdChainlinkOracle {
    using PendlePtOracleLib for IPMarket;

    uint32 public immutable twapDuration;
    address public immutable market;
    address public immutable feed;
    uint8 public immutable feedDecimals;
    address public immutable ptOracle;

    constructor(uint32 _twapDuration, address _market, address _feed, address _ptOracle) {
        twapDuration = _twapDuration;
        market = _market;
        feed = _feed;
        feedDecimals = IChainlinkAggregator(feed).decimals();

        // required only for sample2
        ptOracle = _ptOracle;
    }

    /// @notice direct integration with PendlePtOracleLib, which optimizes gas efficiency.
    /// @notice please checkOracleState() before use
    function getPtPriceSample1() external view virtual returns (uint256) {
        uint256 ptRate = IPMarket(market).getPtToAssetRate(twapDuration);
        uint256 assetPrice = _getUnderlyingAssetPrice();
        return (assetPrice * ptRate) / PMath.ONE;
    }

    /// @notice integration with the PendlePtOracle contract, resulting in a smaller bytecode size and simpler structure
    /// but slightly higher gas usage (~ 4000 gas, 2 external calls & 1 cold code load)
    /// @notice please checkOracleState() before use
    function getPtPriceSample2() external view virtual returns (uint256) {
        uint256 ptRate = IPPtLpOracle(ptOracle).getPtToAssetRate(market, twapDuration);
        uint256 assetPrice = _getUnderlyingAssetPrice();
        return (assetPrice * ptRate) / PMath.ONE;
    }

    function _getUnderlyingAssetPrice() internal view virtual returns (uint256) {
        uint256 rawPrice = uint256(IChainlinkAggregator(feed).latestAnswer());
        return feedDecimals < 18 ? rawPrice * 10 ** (18 - feedDecimals) : rawPrice / 10 ** (feedDecimals - 18);
    }

    // ------------------ NOT TO INCLUDE IN PRODUCTION CODE ------------------

    error IncreaseCardinalityRequired(uint16 cardinalityRequired);
    error AdditionalWaitRequired(uint32 duration);

    /// @notice Call only once for each (market, duration). Once successful, it's permanently valid (also for any shorter duration).
    function checkOracleState() external view {
        (bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied) = IPPtLpOracle(
            ptOracle
        ).getOracleState(market, twapDuration);

        if (increaseCardinalityRequired) {
            // It's required to call IPMarket(market).increaseObservationsCardinalityNext(cardinalityRequired) and wait for
            // at least the twapDuration, to allow data population.
            revert IncreaseCardinalityRequired(cardinalityRequired);
        }

        if (!oldestObservationSatisfied) {
            // It's necessary to wait for at least the twapDuration, to allow data population.
            revert AdditionalWaitRequired(twapDuration);
        }
    }
}
