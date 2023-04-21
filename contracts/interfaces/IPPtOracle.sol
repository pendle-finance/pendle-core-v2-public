// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPPtOracle {
    function getPtToAssetRate(
        address market,
        uint32 duration
    ) external view returns (uint256 ptToAssetRate);

    function getOracleState(
        address market,
        uint32 duration
    )
        external
        view
        returns (
            bool increaseCardinalityRequired,
            uint16 cardinalityRequired,
            bool oldestObservationSatisfied
        );
}
