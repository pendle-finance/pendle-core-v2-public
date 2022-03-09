// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "./IPBaseToken.sol";

interface IPYieldToken is IPBaseToken {
    function tokenizeYield(address to) external returns (uint256 amountMinted);

    function redeemUnderlying(address to) external returns (uint256 amountRedeemed);

    function redeemDueInterest(address user) external returns (uint256 dueInterest);

    function redeemDueRewards(address user) external returns (uint256[] memory dueRewards);

    function LYT() external view returns (address);

    function OT() external view returns (address);
}
