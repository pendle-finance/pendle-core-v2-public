// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IVenusComptroller {
    function claimVenus(address holder, address[] memory vTokens) external;
}
