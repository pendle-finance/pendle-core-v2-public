// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEUSD {
    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256);

    function getSharesByMintedEUSD(uint256 _EUSDAmount) external view returns (uint256);

    function getMintedEUSDByShares(uint256 _sharesAmount) external view returns (uint256);

    function sharesOf(address _account) external view returns (uint256);
}
