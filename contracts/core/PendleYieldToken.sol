// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleBaseToken.sol";
import "../LiquidYieldToken/LiquidYieldToken.sol";
import "../interfaces/IPYieldToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../libraries/math/FixedPoint.sol";
import "../libraries/helpers/ArrayLib.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

// probably should abstract more math to libraries
contract PendleYieldToken is PendleBaseToken, IPYieldToken {
    using FixedPoint for uint256;
    using ArrayLib for uint256[];
    using SafeERC20 for IERC20;

    struct UserData {
        uint256 lastLytIndex;
        uint256 dueInterest;
        uint256[] dueRewards;
        uint256[] lastParamL;
    }

    address public immutable LYT;
    address public immutable OT;

    /// params to do interests & rewards accounting
    uint256 public lastLytBalance;
    uint256 public lastLytIndexBeforeExpiry;
    uint256[] public paramL;

    /// params to do fee accounting
    uint256[] public totalRewardsPostExpiry;
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

        address[] memory rewards = LiquidYieldToken(LYT).getRewardTokens();

        paramL = new uint256[](rewards.length);
        paramL.setValue(1);

        totalRewardsPostExpiry = new uint256[](rewards.length);
    }

    /**
     * @notice this function splits lyt into OT + YT of equal qty
     * @dev the lyt to tokenize has to be pre-transferred to this contract prior to the function call
     */
    function mintYO(address recipient) public returns (uint256 amountYOOut) {
        uint256 amountToTokenize = _receiveLyt();

        amountYOOut = _calcAmountToMint(amountToTokenize);

        _mint(recipient, amountYOOut);

        IPOwnershipToken(OT).mintByYT(recipient, amountYOOut);
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
    }

    function redeemDueRewards(address user) public returns (uint256[] memory rewardsOut) {
        _updateDueRewards(user);

        address[] memory rewardTokens = LiquidYieldToken(LYT).getRewardTokens();

        rewardsOut = data[user].dueRewards;
        data[user].dueRewards.setValue(0);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20(rewardTokens[i]).safeTransfer(user, rewardsOut[i]);
        }
    }

    function getLytIndexBeforeExpiry() public returns (uint256 exchangeRate) {
        if (isExpired()) return lastLytIndexBeforeExpiry;
        lastLytIndexBeforeExpiry = LiquidYieldToken(LYT).lytIndexCurrent();
    }

    function withdrawFeeToTreasury() public {
        address[] memory rewardTokens = LiquidYieldToken(LYT).getRewardTokens();
        uint256 length = rewardTokens.length;
        address treasury = IPYieldContractFactory(factory).treasury();

        for (uint256 i = 0; i < length; i++) {
            if (totalRewardsPostExpiry[i] > 0) {
                IERC20(rewardTokens[i]).safeTransfer(treasury, totalRewardsPostExpiry[i]);
                totalRewardsPostExpiry[i] = 0;
            }
        }

        if (totalProtocolFee > 0) {
            IERC20(LYT).safeTransfer(treasury, totalProtocolFee);
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

    function _updateDueRewards(address user) internal {
        _updateParamL();

        if (data[user].lastParamL.length == 0) {
            data[user].lastParamL = paramL;
            return;
        }

        uint256 principal = balanceOf(user);

        uint256[] memory rewardsAmountPerYT = paramL.sub(data[user].lastParamL);

        uint256[] memory rewardsFromYT = rewardsAmountPerYT.mulDown(principal);

        data[user].dueRewards.addEq(rewardsFromYT);

        data[user].lastParamL = paramL;
    }

    function _updateParamL() internal {
        uint256[] memory incomeRewards = LiquidYieldToken(LYT).redeemReward();

        // if YT has already expired, all the rewards go to the governance
        if (isExpired()) {
            totalRewardsPostExpiry.addEq(incomeRewards);
            return;
        }

        uint256 totalYT = totalSupply();

        if (totalYT != 0) {
            uint256[] memory incomePerYT = incomeRewards.mul(FixedPoint.ONE).divDown(totalYT);
            paramL = paramL.add(incomePerYT);
        }
    }

    function _calcAmountToMint(uint256 amount) internal returns (uint256) {
        return amount.mulDown(getLytIndexBeforeExpiry());
    }

    function _calcAmountRedeemable(uint256 amount) internal returns (uint256) {
        return amount.divDown(getLytIndexBeforeExpiry());
    }

    function _receiveLyt() internal returns (uint256 amount) {
        uint256 balanceLYT = IERC20(LYT).balanceOf(address(this));
        amount = balanceLYT - lastLytBalance;
        lastLytBalance = balanceLYT;
        require(amount > 0, "RECEIVE_ZERO");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        if (from != address(0) && from != address(this)) {
            _updateDueInterest(from);
            _updateDueRewards(from);
        }
        if (to != address(0) && to != address(this)) {
            _updateDueInterest(to);
            _updateDueRewards(to);
        }
    }
}
/*INVARIANTS TO CHECK
- supply OT == supply YT
- reentrancy check
*/
