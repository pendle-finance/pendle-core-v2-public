// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IWstETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);

    function unwrap(uint256 _wstETHAmount) external returns (uint256);

    function stETH() external view returns (address);

    function stEthPerToken() external view returns (uint256);
}
