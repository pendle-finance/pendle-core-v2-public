//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {TokenHelper} from "../../core/libraries/TokenHelper.sol";
import {IMoneyMarket, MarketCtx} from "../../interfaces/IMoneyMarket.sol";
import {IPLoopPositionBoxFactory} from "../../interfaces/IPLoopPositionBoxFactory.sol";
import {IPPTLooper} from "../../interfaces/IPPTLooper.sol";

abstract contract BaseMoneyMarket is IMoneyMarket, TokenHelper {
    IPPTLooper public immutable PT_LOOPER;
    IPLoopPositionBoxFactory public immutable POSITION_BOX_FACTORY;

    constructor(address ptLooper) {
        PT_LOOPER = IPPTLooper(ptLooper);
        POSITION_BOX_FACTORY = PT_LOOPER.POSITION_BOX_FACTORY();
    }

    modifier onlyPtLooper() {
        require(msg.sender == address(PT_LOOPER), "MoneyMarket: unauthorized");
        _;
    }

    modifier onlyPositionBoxFactory() {
        require(msg.sender == address(POSITION_BOX_FACTORY), "MoneyMarket: unauthorized");
        _;
    }

    function initialize(MarketCtx memory ctx) external override onlyPositionBoxFactory {
        _initialize(ctx);
    }

    function lend(MarketCtx memory ctx, uint256 amount)
        external
        override
        onlyPtLooper
        returns (uint256 lent, uint256 postCollateralBalance)
    {
        uint256 balanceBefore = collateralBalance(ctx);
        if (amount == 0) return (0, balanceBefore);
        lent = _lend(ctx, amount);
        postCollateralBalance = lent + balanceBefore;
        emit Lent(ctx.box, ctx.collateral, lent, balanceBefore);
    }

    function withdraw(MarketCtx memory ctx, uint256 amount)
        external
        override
        onlyPtLooper
        returns (uint256 withdrawn, uint256 postCollateralBalance)
    {
        uint256 balanceBefore = collateralBalance(ctx);
        if (amount == 0 || balanceBefore == 0) return (0, balanceBefore);
        withdrawn = _withdraw(ctx, amount);
        postCollateralBalance = balanceBefore - withdrawn;
        emit Withdrawn(ctx.box, ctx.collateral, withdrawn, balanceBefore);
    }

    function borrow(MarketCtx memory ctx, uint256 amount)
        external
        override
        onlyPtLooper
        returns (uint256 borrowed, uint256 postDebtBalance)
    {
        uint256 balanceBefore = debtBalance(ctx);
        if (amount == 0) return (0, balanceBefore);
        borrowed = _borrow(ctx, amount);
        postDebtBalance = borrowed + balanceBefore;
        emit Borrowed(ctx.box, ctx.debtAsset, borrowed, balanceBefore);
    }

    function repay(MarketCtx memory ctx, uint256 amount)
        external
        override
        onlyPtLooper
        returns (uint256 repaid, uint256 postDebtBalance)
    {
        uint256 balanceBefore = debtBalance(ctx);
        if (amount == 0 || balanceBefore == 0) return (0, balanceBefore);
        repaid = _repay(ctx, amount, balanceBefore);
        postDebtBalance = balanceBefore - repaid;
        emit Repaid(ctx.box, ctx.debtAsset, repaid, balanceBefore);
    }

    function claimRewards(
        MarketCtx memory ctx,
        address extRewardController,
        bytes calldata data,
        address[] memory rewardTokens
    ) external onlyPtLooper returns (uint256[] memory claimedAmount) {
        uint256 n = rewardTokens.length;
        uint256[] memory preBalance = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            preBalance[i] = _selfBalance(rewardTokens[i]);
        }

        (bool success,) = extRewardController.call(data);
        require(success, "MoneyMarket: claimRewards failed");

        address owner = ctx.box.OWNER();
        claimedAmount = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            claimedAmount[i] = _selfBalance(rewardTokens[i]) - preBalance[i];
            _transferOut(rewardTokens[i], owner, claimedAmount[i]);
        }

        emit RewardsClaimed(extRewardController, rewardTokens, claimedAmount);
    }

    // ========== View functions ==========

    function collateralBalance(MarketCtx memory ctx) public virtual returns (uint256);
    function debtBalance(MarketCtx memory ctx) public virtual returns (uint256);
    function oraclePtDebtRate(MarketCtx memory ctx) public view virtual returns (uint256 rate);

    // ========== Internal implementation ==========

    function _initialize(MarketCtx memory ctx) internal virtual;

    function _lend(MarketCtx memory ctx, uint256 amount) internal virtual returns (uint256 actualAmount);

    function _withdraw(MarketCtx memory ctx, uint256 amount) internal virtual returns (uint256 actualAmount);

    function _borrow(MarketCtx memory ctx, uint256 amount) internal virtual returns (uint256 actualAmount);

    function _repay(MarketCtx memory ctx, uint256 amount, uint256 balanceBefore)
        internal
        virtual
        returns (uint256 actualAmount);
}
