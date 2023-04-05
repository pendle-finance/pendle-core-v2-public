// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IFrxEthMinter {
    function frxETHToken() external view returns (address);

    function sfrxETHToken() external view returns (address);

    function submitAndDeposit(address recipient) external payable returns (uint256 shares);
}
