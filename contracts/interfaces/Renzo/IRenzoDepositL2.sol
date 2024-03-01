// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRenzoDepositL2 {
    function connext() external view returns (address);

    function swapKey() external view returns (bytes32);

    function collateralToken() external view returns (address);

    function deposit(uint256 _amountIn, uint256 _minOut, uint256 _deadline) external returns (uint256);

    function lastPrice() external view returns (uint256);

    function bridgeRouterFeeBps() external view returns (uint256);
}
