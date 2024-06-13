// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IMellowVault {
    function underlyingTvl() external view returns (address[] memory tokens, uint256[] memory amounts);

    function deposit(
        address to,
        uint256[] memory amounts,
        uint256 minLpAmount,
        uint256 deadline,
        uint256 referralCode
    ) external returns (uint256[] memory actualAmounts, uint256 lpAmount);

    function deposit(
        address to,
        uint256[] memory amounts,
        uint256 minLpAmount,
        uint256 deadline
    ) external returns (uint256[] memory actualAmounts, uint256 lpAmount);

    function configurator() external view returns (address);
}
