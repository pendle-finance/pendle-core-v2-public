// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPPYLpOracle {
    event SetBlockCycleNumerator(uint16 newBlockCycleNumerator);

    function getPtToAssetRate(address market, uint32 duration) external view returns (uint256);

    function getYtToAssetRate(address market, uint32 duration) external view returns (uint256);

    function getLpToAssetRate(address market, uint32 duration) external view returns (uint256);

    function getPtToSyRate(address market, uint32 duration) external view returns (uint256);

    function getYtToSyRate(address market, uint32 duration) external view returns (uint256);

    function getLpToSyRate(address market, uint32 duration) external view returns (uint256);

    function getOracleState(
        address market,
        uint32 duration
    )
        external
        view
        returns (bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied);
}
