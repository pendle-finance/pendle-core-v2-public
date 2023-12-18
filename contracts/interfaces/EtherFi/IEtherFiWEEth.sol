// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEtherFiWEEth {
    function wrap(uint256 _eETHAmount) external returns (uint256);

    function unwrap(uint256 _weETHAmount) external returns (uint256);

    function eETH() external view returns (address);

    function liquidityPool() external view returns (address);
}
