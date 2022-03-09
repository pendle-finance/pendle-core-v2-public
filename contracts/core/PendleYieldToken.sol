// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleBaseToken.sol";
import "../interfaces/IPLiquidYieldToken.sol";
import "../interfaces/IPYieldToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../libraries/math/FixedPoint.sol";
import "../libraries/helpers/ArrayLib.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";

// probably should abstract more math to libraries
contract PendleYieldToken is PendleBaseToken, IPYieldToken {
    using FixedPoint for uint256;
    using ArrayLib for uint256[];

    address public immutable LYT;
    address public immutable OT;
    uint256 public reserveLYT;

    uint256 public lastRateBeforeExpiry;
    mapping(address => uint256) public lastRate;
    mapping(address => mapping(address => uint256)) public contractDebt;

    // rewards stuff
    mapping(address => uint256[]) public lastParamL;
    uint256[] public paramL;

    // caching
    uint256 public immutable lenRewards;

    constructor(
        address _LYT,
        address _OT,
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256 _expiry
    ) PendleBaseToken(_name, _symbol, __decimals, _expiry) {
        LYT = _LYT;
        // require OT YT to be a match (can only in here or OT since we do create2)
        OT = _OT;

        address[] memory rewards = IPLiquidYieldToken(LYT).getRewardTokens();
        lenRewards = rewards.length;

        paramL = new uint256[](lenRewards);
        paramL.setValue(1);
    }

    function tokenizeYield(address to) external returns (uint256 amountMinted) {
        uint256 amountToTokenize = _receiveLYT();

        amountMinted = _calcAmountToMint(amountToTokenize);

        IPOwnershipToken(OT).mintByYT(to, amountMinted);
        _mint(to, amountMinted);
    }

    function redeemUnderlying(address to) external returns (uint256 amountRedeemed) {
        bool isYTExpired = (expiry < block.timestamp);
        uint256 amountToRedeem = Math.min(
            IERC20(OT).balanceOf(address(this)),
            balanceOf(address(this))
        );

        if (isYTExpired) {
            IPOwnershipToken(OT).burnByYT(address(this), amountToRedeem);
        } else {
            IPOwnershipToken(OT).burnByYT(address(this), amountToRedeem);
            // maybe skip the update here?
            _burn(address(this), amountToRedeem);
        }

        amountRedeemed = _calcAmountRedeemable(amountToRedeem);

        IERC20(LYT).transfer(to, amountRedeemed);
    }

    function redeemDueInterest(address user) external returns (uint256 dueInterest) {
        _updateDueInterests(user);
        dueInterest = contractDebt[user][address(LYT)];
        contractDebt[user][address(LYT)] = 0;

        IERC20(LYT).transfer(user, dueInterest);
    }

    function redeemDueRewards(address user) external returns (uint256[] memory dueRewards) {
        _updateDueRewards(user);
        dueRewards = new uint256[](lenRewards);

        for (uint256 i = 0; i < lenRewards; i++) {
            address rewardToken = IPLiquidYieldToken(LYT).rewardTokens(i);
            dueRewards[i] = contractDebt[user][rewardToken];
            contractDebt[user][rewardToken] = 0;

            IERC20(rewardToken).transfer(user, dueRewards[i]);
        }
    }

    function getExchangeRateBeforeExpiry() internal returns (uint256 exchangeRate) {
        if (block.timestamp > expiry) {
            return lastRateBeforeExpiry;
        }
        lastRateBeforeExpiry = IPLiquidYieldToken(LYT).exchangeRateCurrent();
    }

    function _updateDueInterests(address user) internal {
        uint256 prevRate = lastRate[user];
        uint256 currentRate = getExchangeRateBeforeExpiry();
        uint256 principal = balanceOf(user);

        lastRate[user] = currentRate;

        if (prevRate == 0 || prevRate == currentRate) {
            return;
        }

        uint256 interestFromYT = (principal * (currentRate - prevRate)).divDown(
            prevRate * currentRate
        );

        contractDebt[user][address(LYT)] += interestFromYT;
    }

    function _updateDueRewards(address user) internal {
        _updateParamL();

        if (lastParamL[user].length == 0) {
            lastParamL[user] = paramL;
            return;
        }

        uint256 principal = balanceOf(user);
        uint256[] memory rewardsAmountPerYT = paramL.sub(lastParamL[user]);
        uint256[] memory rewardsFromYT = rewardsAmountPerYT.mulDown(principal);

        for (uint256 i = 0; i < lenRewards; i++) {
            contractDebt[user][IPLiquidYieldToken(LYT).rewardTokens(i)] += rewardsFromYT[i];
        }

        lastParamL[user] = paramL;
    }

    function _updateParamL() internal {
        uint256[] memory incomeRewards = IPLiquidYieldToken(LYT).redeemReward();
        // this part can check if it has already expired then move all the rewards to treasury
        // but also, need to make sure near expiry there is a redeem to update everthing

        uint256 totalYT = totalSupply();

        if (totalYT != 0) {
            uint256[] memory incomePerYT = incomeRewards.mul(FixedPoint.ONE).divDown(totalYT);
            paramL = paramL.add(incomePerYT);
        }
    }

    function _calcAmountToMint(uint256 amount) internal returns (uint256) {
        return amount.mulDown(getExchangeRateBeforeExpiry());
    }

    function _calcAmountRedeemable(uint256 amount) internal returns (uint256) {
        return amount.divDown(getExchangeRateBeforeExpiry());
    }

    function _receiveLYT() internal returns (uint256 amount) {
        uint256 balanceLYT = IERC20(LYT).balanceOf(address(this));
        amount = balanceLYT - reserveLYT;
        reserveLYT = balanceLYT;
        require(amount > 0, "RECEIVE_ZERO");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        if (from != address(0)) {
            _updateDueInterests(from);
            _updateDueRewards(from);
        }
        if (to != address(0)) {
            _updateDueInterests(to);
            _updateDueRewards(to);
        }
    }
}
