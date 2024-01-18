// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRenzoOracle {
    function lookupTokenValue(address token, uint256 amount) external view returns (uint256);

    function calculateMintAmount(uint256 tvl, uint256 value, uint256 supply) external view returns (uint256);
}
