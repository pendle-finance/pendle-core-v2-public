// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IAaveV3AToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function scaledBalanceOf(address user) external view returns (uint256);

    function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);

    function scaledTotalSupply() external view returns (uint256);

    function getPreviousIndex(address user) external view returns (uint256);

    function getIncentivesController() external view returns (address);
}
