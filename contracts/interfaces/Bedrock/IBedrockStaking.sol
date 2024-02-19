// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBedrockStaking {
    function mint(uint256 minToMint, uint256 deadline) external payable returns (uint256 minted);

    function exchangeRatio() external view returns (uint256);

    function currentReserve() external view returns (uint256);
}
