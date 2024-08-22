// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICornSilo {
    function deposit(address token, uint256 assets) external returns (uint256 shares);

    function redeemToken(address token, uint256 shares) external returns (uint256 assets);
}
