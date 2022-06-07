// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

interface IPActionRedeem {
    function redeemDueIncome(
        address user,
        address[] calldata scys,
        address[] calldata yieldTokens,
        address[] calldata markets
    )
        external
        returns (
            uint256[][] memory scyRewards,
            uint256[] memory ytInterests,
            uint256[][] memory ytRewards,
            uint256[][] memory marketRewards
        );
}
