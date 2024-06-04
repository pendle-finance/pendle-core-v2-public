// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendlePYOracleLib.sol";
import "./PendleLpOracleLib.sol";
import "../interfaces/IPPYLpOracle.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";

// This is a pre-deployed version of PendlePtOracleLib & PendleLpOracleLib with additional utility functions.
// Use of this contract rather than direct library integration resulting in a smaller bytecode size and simpler structure
// but slightly higher gas usage (~ 4000 gas, 2 external calls & 1 cold code load)
contract PendlePYLpOracle is BoringOwnableUpgradeable, IPPYLpOracle {
    using PendlePYOracleLib for IPMarket;
    using PendleLpOracleLib for IPMarket;

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

    constructor() {
        _disableInitializers();
    }

    function initialize(uint16 _blockCycleNumerator) external initializer {
        __BoringOwnable_init();
        _setBlockCycleNumerator(_blockCycleNumerator);
    }

    // Refer to https://docs.pendle.finance/Home on how to use the oracle

    /*///////////////////////////////////////////////////////////////
                    PT, YT, LP to SY
    //////////////////////////////////////////////////////////////*/

    function getPtToSyRate(address market, uint32 duration) external view returns (uint256) {
        return IPMarket(market).getPtToSyRate(duration);
    }

    function getYtToSyRate(address market, uint32 duration) external view returns (uint256) {
        return IPMarket(market).getYtToSyRate(duration);
    }

    function getLpToSyRate(address market, uint32 duration) external view returns (uint256) {
        return IPMarket(market).getLpToSyRate(duration);
    }

    /*///////////////////////////////////////////////////////////////
                    PT, YT, LP to Asset
    //////////////////////////////////////////////////////////////*/

    /// @notice make sure you have taken into account the risk of not being able to withdraw from SY to Asset
    function getPtToAssetRate(address market, uint32 duration) external view returns (uint256) {
        return IPMarket(market).getPtToAssetRate(duration);
    }

    function getYtToAssetRate(address market, uint32 duration) external view returns (uint256) {
        return IPMarket(market).getYtToAssetRate(duration);
    }

    function getLpToAssetRate(address market, uint32 duration) external view returns (uint256) {
        return IPMarket(market).getLpToAssetRate(duration);
    }

    /*///////////////////////////////////////////////////////////////
                        Utility functions
    //////////////////////////////////////////////////////////////*/

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

    // --- Owner-Only Functions ---
    function setBlockCycleNumerator(uint16 newBlockCycleNumerator) external onlyOwner {
        _setBlockCycleNumerator(newBlockCycleNumerator);
    }

    function _setBlockCycleNumerator(uint16 newBlockCycleNumerator) internal {
        if (newBlockCycleNumerator < BLOCK_CYCLE_DENOMINATOR) {
            revert InvalidBlockRate(newBlockCycleNumerator);
        }

        blockCycleNumerator = newBlockCycleNumerator;
        emit SetBlockCycleNumerator(newBlockCycleNumerator);
    }
}
