// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "./IPBaseToken.sol";
import "../SuperComposableYield/implementations/IRewardManager.sol";

interface IPYieldToken is IPBaseToken, IRewardManager {
    function mintYO(address receiverOT, address receiverYT) external returns (uint256 amountYOOut);

    function redeemYO(address receiver) external returns (uint256 amountScyOut);

    // minimum of OT & YT balance

    function redeemDueInterest(address user) external returns (uint256 interestOut);

    function redeemDueRewards(address user) external returns (uint256[] memory rewardsOut);

    function updateGlobalReward() external;

    function updateUserReward(address user) external;

    function updateUserInterest(address user) external;

    function getInterestData(address user)
        external
        view
        returns (uint256 lastScyIndex, uint256 dueInterest);

    function getScyIndexBeforeExpiry() external returns (uint256 res);

    function withdrawFeeToTreasury() external;

    function SCY() external view returns (address);

    function OT() external view returns (address);
}
