// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleBaseToken.sol";
import "../LiquidYieldToken/ILiquidYieldToken.sol";
import "../interfaces/IPYieldToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../libraries/math/FixedPoint.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "../LiquidYieldToken/implementations/LYTUtils.sol";
import "../LiquidYieldToken/implementations/RewardManager.sol";

// probably should abstract more math to libraries
contract PendleYieldToken is PendleBaseToken, IPYieldToken, RewardManager {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;

    struct UserData {
        uint256 lastLytIndex;
        uint256 dueInterest;
    }

    address public immutable LYT;
    address public immutable OT;

    /// params to do interests & rewards accounting
    uint256 public lastLytBalance;
    uint256 public lastLytIndexBeforeExpiry;
    uint256[] public paramL;

    /// params to do fee accounting
    mapping(address => uint256) public totalRewardsPostExpiry;
    uint256 public totalProtocolFee;

    mapping(address => UserData) public data;

    constructor(
        address _LYT,
        address _OT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _expiry) {
        LYT = _LYT;
        OT = _OT;
    }

    /**
     * @notice this function splits lyt into OT + YT of equal qty
     * @dev the lyt to tokenize has to be pre-transferred to this contract prior to the function call
     */
    function mintYO(address recipientOT, address recipientYT)
        public
        returns (uint256 amountYOOut)
    {
        uint256 amountToTokenize = _receiveLyt();

        amountYOOut = _calcAmountToMint(amountToTokenize);

        _mint(recipientYT, amountYOOut);

        IPOwnershipToken(OT).mintByYT(recipientOT, amountYOOut);
    }

    /// this function converts YO tokens into lyt, but interests & rewards are not included
    function redeemYO(address recipient) public returns (uint256 amountLytOut) {
        // minimum of OT & YT balance
        uint256 amountYOToRedeem = Math.min(
            IERC20(OT).balanceOf(address(this)),
            balanceOf(address(this))
        );

        IPOwnershipToken(OT).burnByYT(address(this), amountYOToRedeem);

        uint256 amountYtToBurn = isExpired() ? 0 : amountYOToRedeem;

        _burn(address(this), amountYtToBurn);

        amountLytOut = _calcAmountRedeemable(amountYOToRedeem);

        IERC20(LYT).safeTransfer(recipient, amountLytOut);
        _afterTransferOutLYT();
    }

    function redeemDueInterest(address user) public returns (uint256 interestOut) {
        _updateDueInterest(user);

        uint256 interestPreFee = data[user].dueInterest;
        data[user].dueInterest = 0;

        uint256 feeRate = IPYieldContractFactory(factory).interestFeeRate();
        uint256 feeAmount = interestPreFee.mulDown(feeRate);
        totalProtocolFee += feeAmount;

        interestOut = interestPreFee - feeAmount;
        IERC20(LYT).safeTransfer(user, interestOut);
        _afterTransferOutLYT();
    }

    function redeemDueRewards(address user) public returns (uint256[] memory rewardsOut) {
        _updateUserReward(user, balanceOf(user), totalSupply());
        rewardsOut = _doTransferOutRewardsForUser(user);
    }

    function updateGlobalReward() public virtual {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, totalSupply());
    }

    function updateUserReward(address user) public virtual {
        _updateUserReward(user, balanceOf(user), totalSupply());
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

    function _redeemExternalReward() internal virtual override {
        ILiquidYieldToken(LYT).redeemReward(address(this));
    }

    function getRewardTokens()
        public
        view
        virtual
        override(RewardManager)
        returns (address[] memory)
    {
        return ILiquidYieldToken(LYT).getRewardTokens();
    }

    function getLytIndexBeforeExpiry() public returns (uint256 res) {
        if (isExpired()) return res = lastLytIndexBeforeExpiry;
        res = ILiquidYieldToken(LYT).lytIndexCurrent();
        lastLytIndexBeforeExpiry = res;
    }

    function withdrawFeeToTreasury() public {
        address[] memory rewardTokens = ILiquidYieldToken(LYT).getRewardTokens();
        uint256 length = rewardTokens.length;
        address treasury = IPYieldContractFactory(factory).treasury();

        for (uint256 i = 0; i < length; i++) {
            address token = rewardTokens[i];
            uint256 outAmount = totalRewardsPostExpiry[token];
            if (outAmount > 0) IERC20(rewardTokens[i]).safeTransfer(treasury, outAmount);
            totalRewardsPostExpiry[token] = 0;
        }

        if (totalProtocolFee > 0) {
            IERC20(LYT).safeTransfer(treasury, totalProtocolFee);
            _afterTransferOutLYT();
            totalProtocolFee = 0;
        }
    }

    function _updateDueInterest(address user) internal {
        uint256 prevIndex = data[user].lastLytIndex;

        uint256 currentIndex = getLytIndexBeforeExpiry();

        if (prevIndex == 0 || prevIndex == currentIndex) {
            data[user].lastLytIndex = currentIndex;
            return;
        }

        uint256 principal = balanceOf(user);

        uint256 interestFromYT = (principal * (currentIndex - prevIndex)).divDown(
            prevIndex * currentIndex
        );

        data[user].dueInterest += interestFromYT;
        data[user].lastLytIndex = currentIndex;
    }

    function _calcAmountToMint(uint256 amount) internal returns (uint256) {
        return LYTUtils.lytToAsset(getLytIndexBeforeExpiry(), amount);
    }

    function _calcAmountRedeemable(uint256 amount) internal returns (uint256) {
        return LYTUtils.assetToLyt(getLytIndexBeforeExpiry(), amount);
    }

    function _receiveLyt() internal returns (uint256 amount) {
        uint256 balanceLYT = IERC20(LYT).balanceOf(address(this));
        amount = balanceLYT - lastLytBalance;
        lastLytBalance = balanceLYT;
        require(amount > 0, "RECEIVE_ZERO");
    }

    function _afterTransferOutLYT() internal {
        lastLytBalance = IERC20(LYT).balanceOf(address(this));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, totalSupply());
        if (from != address(0) && from != address(this)) {
            _updateDueInterest(from);
            _updateUserRewardSkipGlobal(rewardTokens, from, balanceOf(from));
        }
        if (to != address(0) && to != address(this)) {
            _updateDueInterest(to);
            _updateUserRewardSkipGlobal(rewardTokens, to, balanceOf(to));
        }
    }
}
/*INVARIANTS TO CHECK
- supply OT == supply YT
- reentrancy check
*/
