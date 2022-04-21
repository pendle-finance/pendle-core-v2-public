// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleBaseToken.sol";
import "../SuperComposableYield/ISuperComposableYield.sol";
import "../interfaces/IPYieldToken.sol";
import "../interfaces/IPPrincipalToken.sol";
import "../libraries/math/Math.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../SuperComposableYield/SCYUtils.sol";
import "../SuperComposableYield/implementations/RewardManager.sol";
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

    struct InterestData {
        uint256 lastScyIndex;
        uint256 dueInterest;
    }

    address public immutable SCY;
    address public immutable PT;

    /// params to do interests & rewards accounting
    uint256 public lastScyBalance;
    uint256 public lastScyIndexBeforeExpiry;

    /// params to do fee accounting
    mapping(address => uint256) public totalRewardsPostExpiry;
    uint256 public totalInterestPostExpiry;
    uint256 public totalProtocolFee;

    mapping(address => InterestData) internal interestData;

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
        public
        nonReentrant
        returns (uint256 amountPYOut)
    {
        uint256 amountToTokenize = _receiveSCY();

        amountPYOut = _calcAmountToMint(amountToTokenize);

        _mint(receiverYT, amountPYOut);

        IPPrincipalToken(PT).mintByYT(receiverPT, amountPYOut);
    }

    /// @dev this function converts PY tokens into scy, but interests & rewards are not redeemed at the same time
    function redeemPY(address receiver) public nonReentrant returns (uint256 amountScyOut) {
        // minimum of PT & YT balance
        uint256 amountPYToRedeem = IERC20(PT).balanceOf(address(this));
        if (!isExpired()) {
            amountPYToRedeem = Math.min(amountPYToRedeem, balanceOf(address(this)));
            _burn(address(this), amountPYToRedeem);
        }

        IPPrincipalToken(PT).burnByYT(address(this), amountPYToRedeem);

        uint256 amountScyToTreasury;
        (amountScyOut, amountScyToTreasury) = _calcAmountToRedeem(amountPYToRedeem);

        totalInterestPostExpiry += amountScyToTreasury;

        IERC20(SCY).safeTransfer(receiver, amountScyOut);
        _afterTransferOutSCY();
    }

    /**
     * @dev as mentioned in doc, updateDueReward should be placed strictly before every redeemDueInterest
     */
    function redeemDueInterestAndRewards(address user)
        public
        nonReentrant
        returns (uint256 interestOut, uint256[] memory rewardsOut)
    {
        // redeemDueRewards before redeemDueInterest
        updateUserReward(user);
        updateUserInterest(user);
        rewardsOut = _doTransferOutRewardsForUser(user, user);
        interestOut = _doTransferOutDueInterest(user);

        emit RedeemReward(user, rewardsOut);
        emit RedeemInterest(user, interestOut);
    }

    /**
     * @dev as mentioned in doc, updateDueReward should be placed strictly before every redeemDueInterest
     */
    function redeemDueInterest(address user) public nonReentrant returns (uint256 interestOut) {
        updateUserReward(user); /// strictly required, see above for explanation
        updateUserInterest(user);
        interestOut = _doTransferOutDueInterest(user);
        emit RedeemInterest(user, interestOut);
    }

    function redeemDueRewards(address user)
        public
        nonReentrant
        returns (uint256[] memory rewardsOut)
    {
        updateUserReward(user);
        rewardsOut = _doTransferOutRewardsForUser(user, user);
        emit RedeemReward(user, rewardsOut);
    }

    /**
     * @dev updateGlobalReward does not need reentrancy modifier since the rewards
     * will be transfered directly from SCY to YT, without triggering any callbacks
     */
    function updateGlobalReward() external {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, IERC20(SCY).balanceOf(address(this)));
    }

    function updateUserReward(address user) public {
        uint256 impliedScyBalance = getImpliedScyBalance(user);
        uint256 totalScy = IERC20(SCY).balanceOf(address(this));
        _updateUserReward(user, impliedScyBalance, totalScy);
    }

    function updateUserInterest(address user) public {
        uint256 prevIndex = interestData[user].lastScyIndex;

        (, uint256 currentIndexBeforeExpiry) = getScyIndex();

        if (prevIndex == currentIndexBeforeExpiry) return;
        if (prevIndex == 0) {
            interestData[user].lastScyIndex = currentIndexBeforeExpiry;
            return;
        }

        uint256 principal = balanceOf(user);

        uint256 interestFromYT = (principal * (currentIndexBeforeExpiry - prevIndex)).divDown(
            prevIndex * currentIndexBeforeExpiry
        );

        interestData[user].dueInterest += interestFromYT;
        interestData[user].lastScyIndex = currentIndexBeforeExpiry;
    }

    function getInterestData(address user)
        external
        view
        returns (uint256 lastScyIndex, uint256 dueInterest)
    {
        return (interestData[user].lastScyIndex, interestData[user].dueInterest);
    }

    /// @dev override the default updateGlobalReward to avoid distributing the rewards after
    /// YT has expired. Instead, these funds will go to the treasury
    function _updateGlobalReward(address[] memory rewardTokens, uint256 totalSupply)
        internal
        virtual
        override
    {
        if (!_shouldUpdateGlobalReward()) return;
        _redeemExternalReward();

        _initGlobalReward(rewardTokens);

        bool _isExpired = isExpired();
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 currentRewardBalance = IERC20(token).balanceOf(address(this));
            uint256 totalIncomeReward = currentRewardBalance - globalReward[token].lastBalance;

            if (_isExpired) {
                totalRewardsPostExpiry[token] += totalIncomeReward;
            } else if (totalSupply != 0) {
                globalReward[token].index += totalIncomeReward.divDown(totalSupply);
            }

            globalReward[token].lastBalance = currentRewardBalance;
        }
    }

    function _doTransferOutDueInterest(address user) internal returns (uint256 interestOut) {
        uint256 interestPreFee = interestData[user].dueInterest;
        interestData[user].dueInterest = 0;

        uint256 feeRate = IPYieldContractFactory(factory).interestFeeRate();
        uint256 feeAmount = interestPreFee.mulDown(feeRate);
        totalProtocolFee += feeAmount;

        interestOut = interestPreFee - feeAmount;
        IERC20(SCY).safeTransfer(user, interestOut);
        _afterTransferOutSCY();
    }

    function _redeemExternalReward() internal virtual override {
        ISuperComposableYield(SCY).redeemReward(address(this)); // ignore return
    }

    function getRewardTokens()
        public
        view
        virtual
        override(RewardManager, IRewardManager)
        returns (address[] memory)
    {
        return ISuperComposableYield(SCY).getRewardTokens();
    }

    function getScyIndex() public returns (uint256 currentIndex, uint256 lastIndexBeforeExpiry) {
        currentIndex = ISuperComposableYield(SCY).scyIndexCurrent();
        if (isExpired()) {
            lastIndexBeforeExpiry = lastScyIndexBeforeExpiry;
        } else {
            lastScyIndexBeforeExpiry = lastIndexBeforeExpiry = currentIndex;
        }
    }

    /**
     * @dev In case the pool is expired and there is left some SCY not yet redeemed from the contract, the rewards should
     * be claimed before withdrawing to treasury.
     *
     * @dev And since the reward distribution (which based on users' dueInterest) stopped at the scyIndexBeforeExpiry, it is not
     * necessary to updateUserInterest along with reward here.
     */
    function withdrawFeeToTreasury() public {
        address[] memory rewardTokens = getRewardTokens();
        if (isExpired()) {
            _updateGlobalReward(rewardTokens, IERC20(SCY).balanceOf(address(this))); // as refered to the doc above
        }

        uint256 length = rewardTokens.length;
        address treasury = IPYieldContractFactory(factory).treasury();
        uint256[] memory amountRewardsOut = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            address token = rewardTokens[i];
            uint256 outAmount = totalRewardsPostExpiry[token];
            if (outAmount > 0) IERC20(rewardTokens[i]).safeTransfer(treasury, outAmount);
            totalRewardsPostExpiry[token] = 0;
            amountRewardsOut[i] = outAmount;
        }

        uint256 totalScyFee = totalProtocolFee + totalInterestPostExpiry;
        totalProtocolFee = totalInterestPostExpiry = 0;

        if (totalScyFee > 0) {
            IERC20(SCY).safeTransfer(treasury, totalScyFee);
            _afterTransferOutSCY();
        }
        emit WithdrawFeeToTreasury(amountRewardsOut, totalScyFee);
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

    function _receiveSCY() internal returns (uint256 amount) {
        uint256 balanceScy = IERC20(SCY).balanceOf(address(this));
        amount = balanceScy - lastScyBalance;
        require(amount > 0, "RECEIVE_ZERO");
        lastScyBalance = balanceScy;
    }

    function _afterTransferOutSCY() internal {
        lastScyBalance = IERC20(SCY).balanceOf(address(this));
    }

    function getImpliedScyBalance(address user) public view returns (uint256) {
        uint256 scyIndex = interestData[user].lastScyIndex;
        if (scyIndex == 0) return 0;
        return SCYUtils.assetToScy(scyIndex, balanceOf(user)) + interestData[user].dueInterest;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, IERC20(SCY).balanceOf(address(this)));

        // Before the change in YT balance, users' impliedScyBalance is kept unchanged from last time
        // Therefore, both updating due interest before or after due reward work the same.
        if (from != address(0) && from != address(this)) {
            updateUserInterest(from);
            _updateUserRewardSkipGlobal(rewardTokens, from, getImpliedScyBalance(from));
        }
        if (to != address(0) && to != address(this)) {
            updateUserInterest(to);
            _updateUserRewardSkipGlobal(rewardTokens, to, getImpliedScyBalance(to));
        }
    }
}
