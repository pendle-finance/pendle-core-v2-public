// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "./IPBaseToken.sol";
import "./IRewardManager.sol";

interface IPYieldToken is IPBaseToken, IRewardManager {
    event RedeemReward(address indexed user, uint256[] amountRewardsOut);
    event RedeemInterest(address indexed user, uint256 interestOut);

    event WithdrawFeeToTreasury(uint256[] amountRewardsOut, uint256 scyOut);

    function mintPY(address receiverPT, address receiverYT) external returns (uint256 amountPYOut);

    function redeemPY(address receiver) external returns (uint256 amountScyOut);

    function redeemPY(address[] memory receivers, uint256[] memory amounts)
        external
        returns (uint256 amountScyOut);

    // minimum of PT & YT balance

    function redeemDueInterestAndRewards(address user)
        external
        returns (uint256 interestOut, uint256[] memory rewardsOut);

    function redeemDueInterest(address user) external returns (uint256 interestOut);

    function redeemDueRewards(address user) external returns (uint256[] memory rewardsOut);

    function updateAndDistributeReward(address user) external;

    function updateAndDistributeInterest(address user) external;

    function getInterestData(address user)
        external
        view
        returns (uint256 lastScyIndex, uint256 dueInterest);

    function getRewardTokens() external view returns (address[] memory);

    function getScyIndex() external returns (uint256 currentIndex, uint256 lastIndexBeforeExpiry);

    function SCY() external view returns (address);

    function PT() external view returns (address);
}
