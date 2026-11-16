// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IPOracleForSy {
    function latestAnswer() external view returns (int256);
}
