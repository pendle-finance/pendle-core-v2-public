// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma abicoder v2;

interface IPVeToken {
    // ============= USER INFO =============

    function balanceOf(address user) external view returns (uint256);

    /**
     * @return lockedAmount amount of PENDLE user locked
     * @return expiry expiry of users' locked PENDLE
     */
    function readUserInfo(address user)
        external
        view
        returns (uint256 lockedAmount, uint256 expiry);

    // ============= META DATA =============

    function totalSupply() external view returns (uint256);
}
