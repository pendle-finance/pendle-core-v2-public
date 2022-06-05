// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

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

        _updateScyBalance();
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

    function updateAndDistributeReward(address user) external {
        _updateAndDistributeRewards(user);
    }

    function updateAndDistributeInterest(address user) external nonReentrant {
        _updateAndDistributeInterest(user);
    }

    function _updateAndDistributeInterest(address user) internal {
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

    /// @dev override the default updateRewardIndex to avoid distributing the rewards after
    /// YT has expired. Instead, these funds will go to the treasury
    function _updateRewardIndex() internal virtual override {
        if (lastRewardBlock == block.number) return;
        lastRewardBlock = block.number;

        _redeemExternalReward();

        uint256 totalShares = _rewardSharesTotal();

        address[] memory rewardTokens = _getRewardTokens();

        bool _isExpired = isExpired();
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 rewardIndex = rewardState[token].index;

            uint256 currentBalance = _selfBalance(token);
            uint256 rewardAccrued = currentBalance - rewardState[token].lastBalance;

            if (rewardIndex == 0) rewardIndex = INITIAL_REWARD_INDEX;
            if (_isExpired) {
                totalRewardsPostExpiry[token] += rewardAccrued;
            } else if (totalShares != 0) {
                rewardIndex += rewardAccrued.divDown(totalShares);
            }

            rewardState[token] = RewardState({
                index: rewardIndex.Uint128(),
                lastBalance: currentBalance.Uint128()
            });
        }
    }

    function _doTransferOutInterest(address user) internal returns (uint256 interestOut) {
        uint256 interestPreFee = interestData[user].dueInterest;
        interestData[user].dueInterest = 0;

        uint256 feeRate = IPYieldContractFactory(factory).interestFeeRate();
        uint256 feeAmount = interestPreFee.mulDown(feeRate);
        totalProtocolFee += feeAmount;

        interestOut = interestPreFee - feeAmount;
        IERC20(SCY).safeTransfer(user, interestOut);
        _updateScyBalance();
    }

    function _redeemExternalReward() internal virtual override {
        ISuperComposableYield(SCY).claimRewards(address(this)); // ignore return
    }

    /// @dev to be overriden if there is rewards
    function _rewardSharesTotal() internal virtual override returns (uint256) {
        return lastScyBalance;
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
     * necessary to updateAndDistributeRewandDistributeInterest along with reward here.
     */
    function withdrawFeeToTreasury() public {
        address[] memory rewardTokens = _getRewardTokens();
        if (isExpired()) {
            _updateRewardIndex(); // as refered to the doc above
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
            _updateScyBalance();
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

    function _getAmountScyToMint() internal view returns (uint256 amount) {
        amount = IERC20(SCY).balanceOf(address(this)) - lastScyBalance;
        require(amount > 0, "RECEIVE_ZERO");
    }

    function _updateScyBalance() internal {
        lastScyBalance = IERC20(SCY).balanceOf(address(this));
    }

    function getImpliedScyBalance(address user) public view returns (uint256) {
        uint256 scyIndex = interestData[user].lastScyIndex;
        if (scyIndex == 0) {
            return 0;
        }
        return SCYUtils.assetToScy(scyIndex, balanceOf(user)) + interestData[user].dueInterest;
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
