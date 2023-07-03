// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface ISwETH {
    function deposit() external payable;

    function getRate() external view returns (uint256);

    function ethToSwETHRate() external view returns (uint256);
}
