// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendlePtOracleLib.sol";
import "../interfaces/IPPtOracle.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";

contract PendlePtOracle is BoringOwnableUpgradeable, IPPtOracle {
    using PendlePtOracleLib for IPMarket;

    error InvalidBlockRate(uint256 blockCycleNumerator);
    error TwapDurationTooLarge(uint32 duration, uint32 cardinalityRequired);

    /// @notice Oracles will be created ensuring a lowerbound in PendleMarket oracle's cardinality
    /// @dev Cardinality lowerbound will be calculated as twap_duration * 1000 / blockCycleNumerator
    /// @dev blockCycleNumerator should be configured so that blockCycleNumerator / 1000 < actual block cycle
    /// @dev blockCycleNumerator should be greater or equal to 1000 since the oracle only records one
    /// rate per timestamp
    /// For example, on Ethereum blockCycleNumerator = 11000, where 11000/1000 = 11 < 12
    ///                 Arbitrum blockCycleNumerator = 1000, since we can't do better than this
    uint16 public blockCycleNumerator;
    uint16 public constant BLOCK_CYCLE_DENOMINATOR = 1000;

    constructor(uint16 _blockCycleNumerator) initializer {
        __BoringOwnable_init();
        setBlockCycleNumerator(_blockCycleNumerator);
    }

    function setBlockCycleNumerator(uint16 newBlockCycleNumerator) public onlyOwner {
        if (newBlockCycleNumerator < BLOCK_CYCLE_DENOMINATOR) {
            revert InvalidBlockRate(newBlockCycleNumerator);
        }

        blockCycleNumerator = newBlockCycleNumerator;
        emit SetBlockCycleNumerator(newBlockCycleNumerator);
    }

    /**
     * This function returns the twap rate PT/Asset on market
     * @param market market to get rate from
     * @param duration twap duration
     */
    function getPtToAssetRate(address market, uint32 duration) external view returns (uint256 ptToAssetRate) {
        ptToAssetRate = IPMarket(market).getPtToAssetRate(duration);
    }

    /**
     * A check function for the cardinality status of the market
     * @param market PendleMarket address
     * @param duration twap duration
     * @return increaseCardinalityRequired a boolean indicates whether the cardinality should be increased to serve the duration
     * @return cardinalityRequired the amount of cardinality required for the twap duration
     */
    function getOracleState(
        address market,
        uint32 duration
    )
        external
        view
        returns (bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied)
    {
        (, , , uint16 observationIndex, uint16 observationCardinality, uint16 cardinalityReserved) = IPMarket(market)
            ._storage();

        // checkIncreaseCardinalityRequired
        cardinalityRequired = _calcCardinalityRequiredRequired(duration);
        increaseCardinalityRequired = cardinalityReserved < cardinalityRequired;

        // check oldestObservationSatisfied
        (uint32 oldestTimestamp, , bool initialized) = IPMarket(market).observations(
            (observationIndex + 1) % observationCardinality
        );
        if (!initialized) {
            (oldestTimestamp, , ) = IPMarket(market).observations(0);
        }
        oldestObservationSatisfied = oldestTimestamp < block.timestamp - duration;
    }

    function _calcCardinalityRequiredRequired(uint32 duration) internal view returns (uint16) {
        uint32 cardinalityRequired = (duration * BLOCK_CYCLE_DENOMINATOR + blockCycleNumerator - 1) /
            blockCycleNumerator +
            1;
        if (cardinalityRequired > type(uint16).max) {
            revert TwapDurationTooLarge(duration, cardinalityRequired);
        }
        return uint16(cardinalityRequired);
    }
}
