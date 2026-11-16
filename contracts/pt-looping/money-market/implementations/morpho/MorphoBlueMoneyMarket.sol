//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {PMath} from "../../../../core/libraries/math/PMath.sol";
import {MarketCtx} from "../../../../interfaces/IMoneyMarket.sol";
import {BaseMoneyMarket} from "../../BaseMoneyMarket.sol";
import {
    IMorpho,
    Market as MorphoMarketState,
    MarketParams as MorphoMarketParams,
    MorphoMarketId,
    Position as MorphoPosition
} from "./dependencies/IMorpho.sol";
import {SharesMathLib} from "./dependencies/SharesMathLib.sol";

contract MorphoBlueMoneyMarket is BaseMoneyMarket {
    using SharesMathLib for *;

    /// @dev The Morpho oracle price is scaled by 1e36; this converts it to WAD.
    uint256 internal constant ORACLE_PRICE_SCALE_TO_WAD_DIVISOR = 1e36 / PMath.ONE;

    IMorpho public immutable MORPHO;

    constructor(address ptLooper, address _morpho) BaseMoneyMarket(ptLooper) {
        MORPHO = IMorpho(_morpho);
    }

    // ========== IMoneyMarket ==========

    function _initialize(MarketCtx memory ctx) internal virtual override {
        _safeApproveInf(ctx.collateral, address(MORPHO));
        _safeApproveInf(ctx.debtAsset, address(MORPHO));
    }

    function collateralBalance(MarketCtx memory ctx) public view override returns (uint256 balance) {
        balance = _selfPosition(ctx.mmPayload).collateral;
    }

    /// @dev Not `view`: accrues interest before it reads.
    function debtBalance(MarketCtx memory ctx) public override returns (uint256 balance) {
        MORPHO.accrueInterest(_marketParams(ctx.mmPayload));
        MorphoMarketState memory market = _marketState(ctx.mmPayload);
        MorphoPosition memory position = _selfPosition(ctx.mmPayload);
        balance = position.borrowShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    function _lend(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        _transferIn(ctx.collateral, address(ctx.box), amount);
        MORPHO.supplyCollateral({
            marketParams: _marketParams(ctx.mmPayload), assets: amount, onBehalf: address(this), data: ""
        });
        return amount;
    }

    function _borrow(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        (actualAmount,) = MORPHO.borrow({
            marketParams: _marketParams(ctx.mmPayload),
            assets: amount,
            shares: 0,
            onBehalf: address(this),
            receiver: address(ctx.box)
        });
    }

    /// @dev Pulls exactly the assets Morpho takes to burn `actualShares`. That is at most `amount`, and no
    /// dust stays in this contract.
    function _repay(MarketCtx memory ctx, uint256 amount, uint256)
        internal
        virtual
        override
        returns (uint256 actualAmount)
    {
        // `BaseMoneyMarket.repay` called `debtBalance`, which accrued interest.
        MorphoMarketParams memory marketParams = _marketParams(ctx.mmPayload);
        MorphoMarketState memory market = _marketState(ctx.mmPayload);
        uint256 borrowShares = _selfPosition(ctx.mmPayload).borrowShares;
        uint256 actualShares =
            PMath.min(amount.toSharesDown(market.totalBorrowAssets, market.totalBorrowShares), borrowShares);

        if (actualShares > 0) {
            uint256 pullAmount = actualShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
            _transferIn(ctx.debtAsset, address(ctx.box), pullAmount);

            (actualAmount,) = MORPHO.repay({
                marketParams: marketParams, assets: 0, shares: actualShares, onBehalf: address(this), data: ""
            });
        }
    }

    function _withdraw(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        MORPHO.withdrawCollateral({
            marketParams: _marketParams(ctx.mmPayload),
            assets: amount,
            onBehalf: address(this),
            receiver: address(ctx.box)
        });
        return amount;
    }

    /// @dev The oracle is per market (`mmPayload`), so `ctx.collateral` and `ctx.debtAsset` are unused.
    function oraclePtDebtRate(MarketCtx memory ctx) public view override returns (uint256) {
        return _marketParams(ctx.mmPayload).oracle.price() / ORACLE_PRICE_SCALE_TO_WAD_DIVISOR;
    }

    // ========== Internal helpers ==========

    function _marketState(bytes32 mmPayload) internal view returns (MorphoMarketState memory) {
        return MORPHO.market(MorphoMarketId.wrap(mmPayload));
    }

    function _marketParams(bytes32 mmPayload) internal view returns (MorphoMarketParams memory) {
        return MORPHO.idToMarketParams(MorphoMarketId.wrap(mmPayload));
    }

    function _selfPosition(bytes32 mmPayload) internal view returns (MorphoPosition memory) {
        return MORPHO.position(MorphoMarketId.wrap(mmPayload), address(this));
    }
}
