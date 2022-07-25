// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IPInterestManagerYT {
    function userInterest(address user)
        external
        view
        returns (uint128 lastScyIndex, uint128 accruedInterest);
}
