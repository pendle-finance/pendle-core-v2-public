// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IRewardManager.sol";
import "./IPInterestManagerYT.sol";

interface IPYieldToken is IERC20Metadata, IRewardManager, IPInterestManagerYT {
    event RedeemRewards(address indexed user, uint256[] amountRewardsOut);
    event RedeemInterest(address indexed user, uint256 interestOut);

    event WithdrawFeeToTreasury(uint256[] amountRewardsOut, uint256 scyOut);

    function mintPY(address receiverPT, address receiverYT) external returns (uint256 amountPYOut);

    function redeemPY(address receiver) external returns (uint256 amountScyOut);

    function redeemPY(address[] memory receivers, uint256[] memory amounts)
        external
        returns (uint256 amountScyOut);

    function redeemDueInterestAndRewards(address user)
        external
        returns (uint256 interestOut, uint256[] memory rewardsOut);

    function redeemDueInterest(address user) external returns (uint256 interestOut);

    function redeemDueRewards(address user) external returns (uint256[] memory rewardsOut);

    function rewardIndexesCurrent() external returns (uint256[] memory);

    function getScyIndex() external view returns (uint256 currentIndex);

    function getRewardTokens() external view returns (address[] memory);

    function SCY() external view returns (address);

    function PT() external view returns (address);

    function factory() external view returns (address);

    function expiry() external view returns (uint256);

    function isExpired() external view returns (bool);
}
