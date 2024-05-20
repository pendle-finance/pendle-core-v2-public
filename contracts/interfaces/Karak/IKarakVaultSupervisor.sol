// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

interface IKarakVaultSupervisor {
    function deposit(address vault, uint256 amount, uint256 minSharesOut) external returns (uint256 shares);
    function gimmieShares(address vault, uint256 shares) external;
    function returnShares(address vault, uint256 shares) external;
}
