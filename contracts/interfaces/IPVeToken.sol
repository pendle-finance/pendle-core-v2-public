// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma abicoder v2;

interface IPVeToken {
    // ============= USER INFO =============

    function balanceOf(address user) external view returns (uint128);

    function positionData(address user) external view returns (uint128 amount, uint128 expiry);

    // ============= META DATA =============

    function totalSupply() external view returns (uint128);

    function totalSupplyCurrent() external returns (uint128);
}
