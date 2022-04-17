// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleBaseToken.sol";
import "../SuperComposableYield/ISuperComposableYield.sol";
import "../interfaces/IPYieldToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../libraries/math/FixedPoint.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../SuperComposableYield/SCYUtils.sol";
import "../SuperComposableYield/implementations/RewardManager.sol";

/*
With YT yielding more SCYs overtime, which is allowed to be redeemed by users, the reward distribution should
be based on the amount of SCYs that their YT currently represent, plus with their dueInterest.

Due to this, it is required to update users' accruedReward STRICTLY BEFORE their dueInterest & YT is changed,
which includes:
- YT transfers
- RedeemDueInterest
*/
contract PendleYieldToken is PendleBaseToken, IPYieldToken, RewardManager {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    struct UserData {
        uint256 lastScyIndex;
        uint256 dueInterest;
    }

    address public immutable SCY;
    address public immutable OT;

    /// params to do interests & rewards accounting
    uint256 public lastScyBalance;
    uint256 public lastScyIndexBeforeExpiry;
    uint256[] public paramL;

    /// params to do fee accounting
    mapping(address => uint256) public totalRewardsPostExpiry;
    uint256 public totalProtocolFee;

    mapping(address => UserData) public data;

    constructor(
        address _SCY,
        address _OT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _expiry) {
        SCY = _SCY;
        OT = _OT;
    }

    /**
     * @notice this function splits scy into OT + YT of equal qty
     * @dev the scy to tokenize has to be pre-transferred to this contract prior to the function call
     */
    function mintYO(address receiverOT, address receiverYT) public returns (uint256 amountYOOut) {
        uint256 amountToTokenize = _receiveSCY();

        amountYOOut = _calcAmountToMint(amountToTokenize);

        _mint(receiverYT, amountYOOut);

        IPOwnershipToken(OT).mintByYT(receiverOT, amountYOOut);
    }

    /// this function converts YO tokens into scy, but interests & rewards are not included
    function redeemYO(address receiver) public returns (uint256 amountScyOut) {
        // minimum of OT & YT balance
        uint256 amountYOToRedeem = IERC20(OT).balanceOf(address(this));
        if (!isExpired()) {
            amountYOToRedeem = Math.min(amountYOToRedeem, balanceOf(address(this)));
            _burn(address(this), amountYOToRedeem);
        }
        IPOwnershipToken(OT).burnByYT(address(this), amountYOToRedeem);

        amountScyOut = _calcAmountRedeemable(amountYOToRedeem);

        IERC20(SCY).safeTransfer(receiver, amountScyOut);
        _afterTransferOutSCY();
    }

    function redeemDueInterestAndRewards(address user)
        public
        returns (uint256 interestOut, uint256[] memory rewardsOut)
    {
        // redeemDueRewards before redeemDueInterest
        updateUserReward(user);
        updateUserInterest(user);
        rewardsOut = _doTransferOutRewardsForUser(user, user);
        interestOut = _doTransferOutDueInterest(user);
    }

    function redeemDueInterest(address user) public returns (uint256 interestOut) {
        updateUserReward(user); /// strictly required, see above for explanation
        updateUserInterest(user);
        interestOut = _doTransferOutDueInterest(user);
    }

    function redeemDueRewards(address user) public returns (uint256[] memory rewardsOut) {
        updateUserReward(user);
        rewardsOut = _doTransferOutRewardsForUser(user, user);
    }

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
        uint256 prevIndex = data[user].lastScyIndex;

        uint256 currentIndex = getScyIndexBeforeExpiry();

        if (prevIndex == currentIndex) return;
        if (prevIndex == 0) {
            data[user].lastScyIndex = currentIndex;
            return;
        }

        uint256 principal = balanceOf(user);

        uint256 interestFromYT = (principal * (currentIndex - prevIndex)).divDown(
            prevIndex * currentIndex
        );

        data[user].dueInterest += interestFromYT;
        data[user].lastScyIndex = currentIndex;
    }

    function _updateGlobalReward(address[] memory rewardTokens, uint256 totalSupply)
        internal
        virtual
        override
    {
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
        uint256 interestPreFee = data[user].dueInterest;
        data[user].dueInterest = 0;

        uint256 feeRate = IPYieldContractFactory(factory).interestFeeRate();
        uint256 feeAmount = interestPreFee.mulDown(feeRate);
        totalProtocolFee += feeAmount;

        interestOut = interestPreFee - feeAmount;
        IERC20(SCY).safeTransfer(user, interestOut);
        _afterTransferOutSCY();
    }

    function _redeemExternalReward() internal virtual override {
        ISuperComposableYield(SCY).redeemReward(address(this));
    }

    function getRewardTokens()
        public
        view
        virtual
        override(RewardManager)
        returns (address[] memory)
    {
        return ISuperComposableYield(SCY).getRewardTokens();
    }

    function getScyIndexBeforeExpiry() public returns (uint256 res) {
        if (isExpired()) return res = lastScyIndexBeforeExpiry;
        res = ISuperComposableYield(SCY).scyIndexCurrent();
        lastScyIndexBeforeExpiry = res;
    }

    /**
     * In case the pool is expired and there is left some SCY not yet redeemed from the contract, the rewards should
     * be claimed before withdrawing to treasury.
     *
     * And since the reward distribution (which based on users' dueInterest) stopped at the scyIndexBeforeExpiry, it is not
     * necessary to updateDueInterest along with reward here.
     */
    function withdrawFeeToTreasury() public {
        address[] memory rewardTokens = getRewardTokens();
        if (isExpired()) {
            _updateGlobalReward(rewardTokens, IERC20(SCY).balanceOf(address(this))); // as refered to the doc above
        }

        uint256 length = rewardTokens.length;
        address treasury = IPYieldContractFactory(factory).treasury();

        for (uint256 i = 0; i < length; i++) {
            address token = rewardTokens[i];
            uint256 outAmount = totalRewardsPostExpiry[token];
            if (outAmount > 0) IERC20(rewardTokens[i]).safeTransfer(treasury, outAmount);
            totalRewardsPostExpiry[token] = 0;
        }

        if (totalProtocolFee > 0) {
            IERC20(SCY).safeTransfer(treasury, totalProtocolFee);
            _afterTransferOutSCY();
            totalProtocolFee = 0;
        }
    }

    function _calcAmountToMint(uint256 amount) internal returns (uint256) {
        return SCYUtils.scyToAsset(getScyIndexBeforeExpiry(), amount);
    }

    function _calcAmountRedeemable(uint256 amount) internal returns (uint256) {
        return SCYUtils.assetToScy(getScyIndexBeforeExpiry(), amount);
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
        uint256 scyIndex = data[user].lastScyIndex;
        if (scyIndex == 0) return 0;
        return SCYUtils.assetToScy(scyIndex, balanceOf(user)) + data[user].dueInterest;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, IERC20(SCY).balanceOf(address(this)));

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
/*INVARIANTS TO CHECK
- supply OT == supply YT
- reentrancy check
*/
