// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IVault {
    function BASIS_POINTS_DIVISOR() external view returns (uint256);

    function PRICE_PRECISION() external view returns (uint256);

    function priceFeed() external view returns (address);

    function usdg() external view returns (address);
    
    function getFeeBasisPoints(address _token, uint256 _usdgDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) external view returns (uint256);

    function taxBasisPoints() external view returns (uint256);

    function mintBurnFeeBasisPoints() external view returns (uint256);

    function allWhitelistedTokensLength() external view returns (uint256);

    function allWhitelistedTokens(uint256) external view returns (address);

    function whitelistedTokens(address) external view returns (bool);

    function whitelistedTokenCount() external view returns (uint256);

    function adjustForDecimals(uint256 _amount, address _tokenDiv, address _tokenMul) external view returns (uint256);
}
