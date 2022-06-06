// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

interface IPVeToken {
    // ============= USER INFO =============

    function balanceOf(address user) external view returns (uint128);

    function positionData(address user) external view returns (uint128 amount, uint128 expiry);

    // ============= META DATA =============

    function totalSupplyStored() external view returns (uint128);

    function totalSupplyCurrent() external returns (uint128);

    function convertToVeBalance(uint128 amount, uint128 expiry)
        external
        pure
        returns (uint128, uint128);

    function isPositionExpired(address user) external view returns (bool);
}
