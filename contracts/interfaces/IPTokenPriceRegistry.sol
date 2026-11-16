// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPTokenPriceRegistry {
    event MaintainerSet(address indexed maintainer);

    event TokenPriceSet(address indexed token, uint256 price);

    function maintainer() external view returns (address);

    /// @notice USD price scaled by 10**(36 - token decimals): amount * tokenPrice / 1e18 is 18-decimal USD.
    function tokenPrice(address token) external view returns (uint256);

    function setMaintainer(address newMaintainer) external;

    function setTokenPrices(address[] calldata tokens, uint256[] calldata prices) external;
}
