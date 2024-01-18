// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IRenzoRestakeManager {
    function depositETH(uint256 _referralId) external payable;

    function deposit(address _collateralToken, uint256 _amount, uint256 _referralId) external;

    function collateralTokens(uint256 i) external view returns (address);

    function calculateTVLs() external view returns (uint256[][] memory, uint256[] memory, uint256);

    function renzoOracle() external view returns (address);
}
