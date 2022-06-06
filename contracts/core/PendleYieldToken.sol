// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

import "./PendleBaseToken.sol";
import "../interfaces/ISuperComposableYield.sol";
import "../interfaces/IPYieldToken.sol";
import "../interfaces/IPPrincipalToken.sol";
import "../libraries/math/Math.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../libraries/SCYUtils.sol";
import "../SuperComposableYield/base-implementations/RewardManager.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*
With YT yielding more SCYs overtime, which is allowed to be redeemed by users, the reward distribution should
be based on the amount of SCYs that their YT currently represent, plus with their dueInterest.

It has been proven and tested that impliedScyBalance will not change over time, unless users redeem their interest or redeemPY.

Due to this, it is required to update users' accruedReward STRICTLY BEFORE redeeming their interest.
*/
contract PendleYieldToken is PendleBaseToken, RewardManager, IPYieldToken, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;

    struct UserInterest {
        uint128 index;
        uint128 accrued;
    }

    struct InterestState {
        uint128 lastIndexBeforeExpiry;
        uint128 lastBalance;
    }

    address public immutable SCY;
    address public immutable PT;

    InterestState public interestState;
    mapping(address => UserInterest) internal userInterest;

    constructor(
        address _SCY,
        address _PT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _expiry) {
        require(_SCY != address(0) && _PT != address(0), "zero address");
        SCY = _SCY;
        PT = _PT;
    }

    /**
     * @notice this function splits scy into PT + YT of equal qty
     * @dev the scy to tokenize has to be pre-transferred to this contract prior to the function call
     */
    function mintPY(address receiverPT, address receiverYT)
        external
        nonReentrant
        returns (uint256 amountPYOut)
    {
        uint256 amountToTokenize = _getAmountScyToMint();

        amountPYOut = _calcAmountToMint(amountToTokenize);

        _mint(receiverYT, amountPYOut);

        IPPrincipalToken(PT).mintByYT(receiverPT, amountPYOut);

        _updateScyBalance();
    }

    /// @dev this function converts PY tokens into scy, but interests & rewards are not redeemed at the same time
    function redeemPY(address receiver) external nonReentrant returns (uint256 amountScyOut) {
        address[] memory receivers = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        (receivers[0], amounts[0]) = (receiver, type(uint256).max);

        amountScyOut = _redeemPY(receivers, amounts);
    }

    function redeemPY(address[] memory receivers, uint256[] memory amounts)
        external
        nonReentrant
        returns (uint256 amountScyOut)
    {
        amountScyOut = _redeemPY(receivers, amounts);
    }

    /**
     * @dev as mentioned in doc, updateDueReward should be placed strictly before every redeemDueInterest
     */
    function redeemDueInterestAndRewards(address user)
        external
        nonReentrant
        returns (uint256 interestOut, uint256[] memory rewardsOut)
    {
        // redeemDueRewards before redeemDueInterest
        _updateAndDistributeRewards(user);
        _updateAndDistributeInterest(user);
        rewardsOut = _doTransferOutRewards(user, user);
        interestOut = _doTransferOutInterest(user);

        emit RedeemReward(user, rewardsOut);
        emit RedeemInterest(user, interestOut);
    }

    /**
     * @dev as mentioned in doc, _updateAndDistributeRewards should be placed strictly before every _updateAndDistributeInterest
     */
    function redeemDueInterest(address user) external nonReentrant returns (uint256 interestOut) {
        _updateAndDistributeRewards(user); /// strictly required, see above for explanation

        _updateAndDistributeInterest(user);
        interestOut = _doTransferOutInterest(user);
        emit RedeemInterest(user, interestOut);
    }

    function redeemDueRewards(address user)
        external
        nonReentrant
        returns (uint256[] memory rewardsOut)
    {
        _updateAndDistributeRewards(user);

        rewardsOut = _doTransferOutRewards(user, user);
        emit RedeemReward(user, rewardsOut);
    }

    function updateAndDistributeReward(address user) external nonReentrant {
        _updateAndDistributeRewards(user);
    }

    function updateAndDistributeInterest(address user) external nonReentrant {
        _updateAndDistributeInterest(user);
    }

    function _redeemPY(address[] memory receivers, uint256[] memory amounts)
        internal
        returns (uint256 amountScyOut)
    {
        // minimum of PT & YT balance
        uint256 amountPYToRedeem = IERC20(PT).balanceOf(address(this));
        if (!isExpired()) {
            amountPYToRedeem = Math.min(amountPYToRedeem, balanceOf(address(this)));
            _burn(address(this), amountPYToRedeem);
        }

        IPPrincipalToken(PT).burnByYT(address(this), amountPYToRedeem);

        uint256 amountScyToTreasury;
        (amountScyOut, amountScyToTreasury) = _calcAmountToRedeem(amountPYToRedeem);

        if (amountScyToTreasury != 0) {
            IERC20(SCY).safeTransfer(
                IPYieldContractFactory(factory).treasury(),
                amountScyToTreasury
            );
        }

        uint256 totalAmountRemains = amountScyOut;
        for (uint256 i = 0; i < receivers.length; i++) {
            uint256 amount = Math.min(totalAmountRemains, amounts[i]);
            totalAmountRemains -= amount;
            if (amount != 0) IERC20(SCY).safeTransfer(receivers[i], amount);
        }

        _updateScyBalance();
    }

    function _updateAndDistributeInterest(address user) internal {
        uint256 prevIndex = userInterest[user].index;

        (, uint256 currentIndexBeforeExpiry) = getScyIndex();

        if (prevIndex == currentIndexBeforeExpiry) return;
        if (prevIndex == 0) {
            userInterest[user].index = currentIndexBeforeExpiry.Uint128();
            return;
        }

        uint256 principal = balanceOf(user);

        uint256 interestFromYT = (principal * (currentIndexBeforeExpiry - prevIndex)).divDown(
            prevIndex * currentIndexBeforeExpiry
        );

        userInterest[user].accrued += interestFromYT.Uint128();
        userInterest[user].index = currentIndexBeforeExpiry.Uint128();
    }

    function getInterestData(address user)
        external
        view
        returns (uint256 lastScyIndex, uint256 dueInterest)
    {
        return (userInterest[user].index, userInterest[user].accrued);
    }

    /// @dev override the default updateRewardIndex to avoid distributing the rewards after
    /// YT has expired. Instead, these funds will go to the treasury
    function _updateRewardIndex() internal virtual override {
        if (!isExpired()) {
            super._updateRewardIndex();
            return;
        }

        // For the case of expired YT
        if (lastRewardBlock == block.number) return;
        lastRewardBlock = block.number;

        _redeemExternalReward();

        address[] memory rewardTokens = _getRewardTokens();
        address treasury = IPYieldContractFactory(factory).treasury();

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];

            uint256 currentBalance = _selfBalance(token);
            uint256 rewardAccrued = currentBalance - rewardState[token].lastBalance;

            _transferOut(token, treasury, rewardAccrued);
        }
    }

    function _doTransferOutInterest(address user) internal returns (uint256 interestOut) {
        uint256 interestPreFee = userInterest[user].accrued;
        userInterest[user].accrued = 0;

        uint256 feeRate = IPYieldContractFactory(factory).interestFeeRate();
        uint256 feeAmount = interestPreFee.mulDown(feeRate);

        IERC20(SCY).safeTransfer(IPYieldContractFactory(factory).treasury(), feeAmount);

        interestOut = interestPreFee - feeAmount;
        IERC20(SCY).safeTransfer(user, interestOut);
        _updateScyBalance();
    }

    function _redeemExternalReward() internal virtual override {
        ISuperComposableYield(SCY).claimRewards(address(this)); // ignore return
    }

    /// @dev to be overriden if there is rewards
    function _rewardSharesTotal() internal virtual override returns (uint256) {
        return interestState.lastBalance;
    }

    /// @dev to be overriden if there is rewards
    function _rewardSharesUser(address user) internal virtual override returns (uint256) {
        return getImpliedScyBalance(user);
    }

    function _getRewardTokens() internal view override returns (address[] memory) {
        return ISuperComposableYield(SCY).getRewardTokens();
    }

    function getScyIndex() public returns (uint256 currentIndex, uint256 lastIndexBeforeExpiry) {
        currentIndex = ISuperComposableYield(SCY).exchangeRateCurrent();
        if (isExpired()) {
            lastIndexBeforeExpiry = interestState.lastIndexBeforeExpiry;
        } else {
            lastIndexBeforeExpiry = currentIndex;
            interestState.lastIndexBeforeExpiry = lastIndexBeforeExpiry.Uint128();
        }
    }

    function _calcAmountToMint(uint256 amount) internal returns (uint256) {
        (, uint256 lastIndexBeforeExpiry) = getScyIndex();
        return SCYUtils.scyToAsset(lastIndexBeforeExpiry, amount);
    }

    function _calcAmountToRedeem(uint256 amount)
        internal
        returns (uint256 amountToUser, uint256 amountToTreasury)
    {
        (uint256 currentIndex, uint256 lastIndexBeforeExpiry) = getScyIndex();
        uint256 totalRedeemable = SCYUtils.assetToScy(lastIndexBeforeExpiry, amount);
        amountToUser = SCYUtils.assetToScy(currentIndex, amount);
        amountToTreasury = totalRedeemable - amountToUser;
    }

    function _getAmountScyToMint() internal view returns (uint256 amount) {
        amount = IERC20(SCY).balanceOf(address(this)) - interestState.lastBalance;
        require(amount > 0, "RECEIVE_ZERO");
    }

    function _updateScyBalance() internal {
        interestState.lastBalance = IERC20(SCY).balanceOf(address(this)).Uint128();
    }

    function getImpliedScyBalance(address user) public view returns (uint256) {
        uint256 scyIndex = userInterest[user].index;
        if (scyIndex == 0) {
            return 0;
        }
        return SCYUtils.assetToScy(scyIndex, balanceOf(user)) + userInterest[user].accrued;
    }

    function getRewardTokens() external view returns (address[] memory) {
        return _getRewardTokens();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        _updateRewardIndex();

        // Before the change in YT balance, users' impliedScyBalance is kept unchanged from last time
        // Therefore, both updating due interest before or after due reward work the same.
        if (from != address(0) && from != address(this)) {
            _updateAndDistributeInterest(from);
            _distributeUserReward(from);
        }
        if (to != address(0) && to != address(this)) {
            _updateAndDistributeInterest(to);
            _distributeUserReward(to);
        }
    }
}
