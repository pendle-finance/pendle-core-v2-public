// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPActionMisc {
    function consult(address market, uint32 secondsAgo)
        external
        view
        returns (uint96 lnImpliedRateMean);
}
