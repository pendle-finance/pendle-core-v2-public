// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IXGrail is IERC20 {
    function approveUsage(address usage, uint256 amount) external;

    function getUsageApproval(address user, address usage) external view returns (uint256);

    function usageAllocations(address user, address usage) external view returns (uint256);

    function allocate(address usageAddress, uint256 amount, bytes calldata usageData) external;

    function deallocate(address usageAddress, uint256 amount, bytes calldata usageData) external;

    function redeem(uint256 xGrailAmount, uint256 duration) external;

    function finalizeRedeem(uint256 redeemIndex) external;

    function cancelRedeem(uint256 redeemIndex) external;
}
