//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IPPTLooper} from "../../interfaces/IPPTLooper.sol";
import {IMoneyMarketView, Reward, Limits} from "../../interfaces/IMoneyMarketView.sol";
import {IMoneyMarket, MarketCtx, createMarketCtx} from "../../interfaces/IMoneyMarket.sol";
import {IPLoopPositionBoxFactory} from "../../interfaces/IPLoopPositionBoxFactory.sol";
import {IPLoopPositionBox, BoxData} from "../../interfaces/IPLoopPositionBox.sol";
import {LogExpMath} from "../../core/libraries/math/LogExpMath.sol";
import {PMath} from "../../core/libraries/math/PMath.sol";

abstract contract BaseMoneyMarketView is IMoneyMarketView {
    using LogExpMath for uint256;

    string public override moneyMarketName;
    IPPTLooper public immutable PT_LOOPER;
    IPLoopPositionBoxFactory public immutable POSITION_BOX_FACTORY;

    uint256 private constant DAYS_PER_YEAR_SCALED = 365e18;

    constructor(string memory _moneyMarketName, address _ptLooper) {
        moneyMarketName = _moneyMarketName;
        PT_LOOPER = IPPTLooper(_ptLooper);
        POSITION_BOX_FACTORY = PT_LOOPER.POSITION_BOX_FACTORY();
    }

    function moneyMarketBalances(IPLoopPositionBox box)
        public
        override
        returns (uint256 mmPtBalance, uint256 mmDebtBalance)
    {
        return _moneyMarketBalances(box, _boxData(box));
    }

    function thresholds(IPLoopPositionBox box)
        public
        view
        override
        returns (uint256 ltv, uint256 liquidationThreshold)
    {
        return _thresholds(box, _boxData(box));
    }

    function liquidity(IPLoopPositionBox box) public view override returns (uint256 borrowing, uint256 lending) {
        return _liquidity(box, _boxData(box));
    }

    function rewards(IPLoopPositionBox box)
        public
        override
        returns (Reward[] memory borrowing, Reward[] memory lending)
    {
        return _rewards(box, _boxData(box));
    }

    function limits(IPLoopPositionBox box) public view override returns (Limits memory limits_) {
        return _limits(box, _boxData(box));
    }

    function rates(IPLoopPositionBox box) public view override returns (uint256 borrowing, uint256 lending) {
        return _rates(box, _boxData(box));
    }

    function ptDebtRate(IPLoopPositionBox box) public view override returns (uint256) {
        return _ptDebtRate(box, _boxData(box));
    }

    function _moneyMarketBalances(IPLoopPositionBox box, BoxData memory bd)
        internal
        virtual
        returns (uint256 mmPtBalance, uint256 mmDebtBalance)
    {
        IMoneyMarket spokeMM = IMoneyMarket(box.SPOKE_MONEY_MARKET());
        MarketCtx memory ctx = createMarketCtx(box, bd);
        mmPtBalance = spokeMM.collateralBalance(ctx);
        mmDebtBalance = spokeMM.debtBalance(ctx);
    }

    function _ptDebtRate(IPLoopPositionBox box, BoxData memory bd) internal view virtual returns (uint256) {
        return IMoneyMarket(box.SPOKE_MONEY_MARKET()).oraclePtDebtRate(createMarketCtx(box, bd));
    }

    function _thresholds(IPLoopPositionBox box, BoxData memory bd)
        internal
        view
        virtual
        returns (uint256 ltv, uint256 liquidationThreshold);

    function _liquidity(IPLoopPositionBox box, BoxData memory bd)
        internal
        view
        virtual
        returns (uint256 borrowing, uint256 lending);

    function _rates(IPLoopPositionBox box, BoxData memory bd)
        internal
        view
        virtual
        returns (uint256 borrowing, uint256 lending);

    function _rewards(IPLoopPositionBox box, BoxData memory bd)
        internal
        virtual
        returns (Reward[] memory borrowing, Reward[] memory lending)
    {}

    function _boxData(IPLoopPositionBox box) internal view virtual returns (BoxData memory) {
        return POSITION_BOX_FACTORY.boxData(box.BOX_ID());
    }

    /// @dev `rate` is a per-`perSeconds` WAD growth factor. Callers must pre-normalize:
    /// Aave passes `perSeconds = 365 days` (annual WAD) and Morpho passes `perSeconds = 1`
    /// (already per-second WAD). Returns the compounded APY in WAD.
    function _apy(uint256 rate, uint256 perSeconds) internal pure returns (uint256) {
        uint256 dailyRate = rate * 1 days / perSeconds;
        return (dailyRate + PMath.ONE).pow(DAYS_PER_YEAR_SCALED) - PMath.ONE;
    }

    function _limits(IPLoopPositionBox, BoxData memory) internal view virtual returns (Limits memory limits_) {
        limits_.minBorrowing = limits_.minLending = limits_.minBorrowingForRewards = limits_.minLendingForRewards = 0;
        limits_.maxBorrowing = limits_.maxLending = type(uint256).max;
    }
}
