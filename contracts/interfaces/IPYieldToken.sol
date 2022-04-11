// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "./IPBaseToken.sol";

interface IPYieldToken is IPBaseToken {
    function mintYO(address receiverOT, address receiverYT) external returns (uint256 amountYOOut);

    function redeemYO(address receiver) external returns (uint256 amountScyOut);

    function redeemDueInterest(address user) external returns (uint256 interestOut);

    function redeemDueRewards(address user) external returns (uint256[] memory rewardsOut);

    function SCY() external view returns (address);

    function OT() external view returns (address);
}
