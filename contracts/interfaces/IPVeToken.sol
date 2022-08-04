// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

interface IPVeToken {
    // ============= USER INFO =============

    function balanceOf(address user) external view returns (uint128);

    function positionData(address user) external view returns (uint128 amount, uint128 expiry);

    // ============= META DATA =============

    function totalSupplyStored() external view returns (uint128);

    function totalSupplyCurrent() external returns (uint128);

    function totalSupplyAndBlanaceCurrent(address user) external returns (uint128, uint128);
}
