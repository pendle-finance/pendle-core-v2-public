// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IPTokenWithSupplyCap {
    function getAbsoluteSupplyCap() external view returns (uint256);

    function getAbsoluteTotalSupply() external view returns (uint256);
}
