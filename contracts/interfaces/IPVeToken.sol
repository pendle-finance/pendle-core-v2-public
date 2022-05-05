// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma abicoder v2;

interface IPVeToken {

    // ============= USER INFO =============

    function balanceOf(address user) external view returns (uint256);

    function positionData(address user)
        external
        view
        returns (uint256 amount, uint256 expiry);

    // ============= META DATA =============

    function totalSupply() external view returns (uint256);
}
