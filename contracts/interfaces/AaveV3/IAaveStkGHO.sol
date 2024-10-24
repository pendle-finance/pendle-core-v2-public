// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IAaveStkGHO {
    function stake(address to, uint256 amount) external;

    function redeem(address to, uint256 amount) external;

    function claimRewards(address to, uint256 amount) external;

    function getExchangeRate() external view returns (uint216);

    function previewStake(uint256 assets) external view returns (uint256);

    function previewRedeem(uint256 shares) external view returns (uint256);
}
