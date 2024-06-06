// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../interfaces/IPPYLpOracle.sol";
import "../../interfaces/IPMarket.sol";
import "../../core/libraries/math/PMath.sol";
import "../PendleLpOracleLib.sol";

import {AggregatorV2V3Interface as IChainlinkAggregator} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

interface MinimalAggregatorV3Interface {
    /// @notice Returns the precision of the feed.
    function decimals() external view returns (uint8);

    /// @notice Returns Chainlink's `latestRoundData` return values.
    /// @notice Only the `answer` field is used by `MorphoChainlinkOracleV2`.
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract PtUSDeToUSDeChainlinkAdapter is MinimalAggregatorV3Interface {
    using PendlePYOracleLib for IPMarket;
    using PMath for uint256;

    /// @inheritdoc MinimalAggregatorV3Interface
    // @dev The calculated price has 18 decimals precision, whatever the value of `decimals`.
    uint8 public constant decimals = 18;

    /// @notice The description of the price feed.
    string public constant description = "PT USDe to USDe Chainlink Adapter";

    uint32 public immutable duration;

    address public immutable market;

    constructor(address _market, uint32 _duration) {
        market = _market;
        duration = _duration;
    }

    /// @inheritdoc MinimalAggregatorV3Interface
    /// @dev Returns zero for roundId, startedAt, updatedAt and answeredInRound.
    /// @dev Silently overflows if `getPooledEthByShares`'s return value is greater than `type(int256).max`.
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, IPMarket(market).getPtToSyRate(duration).Int(), 0, 0, 0);
    }
}
