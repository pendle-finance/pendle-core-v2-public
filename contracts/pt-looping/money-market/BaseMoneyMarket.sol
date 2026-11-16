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

    function lend(MarketCtx memory ctx, uint256 amount) external override onlyPtLooper returns (uint256 lent) {
        if (amount == 0) return 0;
        return _lend(ctx, amount);
    }

    function withdraw(MarketCtx memory ctx, uint256 amount) external override onlyPtLooper returns (uint256 withdrawn) {
        if (amount == 0) return 0;
        return _withdraw(ctx, amount);
    }

    function borrow(MarketCtx memory ctx, uint256 amount) external override onlyPtLooper returns (uint256 borrowed) {
        if (amount == 0) return 0;
        return _borrow(ctx, amount);
    }

    function repay(MarketCtx memory ctx, uint256 amount) external override onlyPtLooper returns (uint256 repaid) {
        if (amount == 0) return 0;
        uint256 balanceBefore = debtBalance(ctx);
        if (balanceBefore == 0) return 0;
        return _repay(ctx, amount, balanceBefore);
    }

    // ========== View functions ==========

    function debtBalance(MarketCtx memory ctx) public virtual returns (uint256);

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
