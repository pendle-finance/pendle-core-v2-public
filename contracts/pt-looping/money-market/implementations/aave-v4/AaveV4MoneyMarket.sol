//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ISpoke} from "./dependencies/ISpoke.sol";
import {IAaveOracle} from "./dependencies/IAaveOracle.sol";

import {MarketCtx} from "../../../../interfaces/IMoneyMarket.sol";
import {BaseMoneyMarket} from "../../BaseMoneyMarket.sol";
import {AaveV4MMPayloadLib} from "./AaveV4MMPayloadLib.sol";
import {PMath} from "../../../../core/libraries/math/PMath.sol";

contract AaveV4MoneyMarket is BaseMoneyMarket {
    using PMath for uint256;

    constructor(address ptLooper) BaseMoneyMarket(ptLooper) {}

    function _initialize(MarketCtx memory ctx) internal virtual override {
        (ISpoke spoke, uint256 collateralReserveId, uint256 debtReserveId) = AaveV4MMPayloadLib.unwrap(ctx.mmPayload);

        address collateralToken = spoke.getReserve(collateralReserveId).underlying;
        address debtToken = spoke.getReserve(debtReserveId).underlying;
        require(collateralToken == ctx.collateral, "AaveV4MoneyMarket: collateral reserve mismatch");
        require(debtToken == ctx.debtAsset, "AaveV4MoneyMarket: debt reserve mismatch");

        _safeApproveInf(collateralToken, address(spoke));
        _safeApproveInf(debtToken, address(spoke));

        spoke.setUsingAsCollateral({reserveId: collateralReserveId, usingAsCollateral: true, onBehalfOf: address(this)});
    }

    function collateralBalance(MarketCtx memory ctx) public view override returns (uint256 balance) {
        (ISpoke spoke, uint256 collateralReserveId,) = AaveV4MMPayloadLib.unwrap(ctx.mmPayload);
        return spoke.getUserSuppliedAssets(collateralReserveId, address(this));
    }

    function debtBalance(MarketCtx memory ctx) public view override returns (uint256 balance) {
        (ISpoke spoke,, uint256 debtReserveId) = AaveV4MMPayloadLib.unwrap(ctx.mmPayload);
        return spoke.getUserTotalDebt(debtReserveId, address(this));
    }

    function _lend(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        (ISpoke spoke, uint256 collateralReserveId,) = AaveV4MMPayloadLib.unwrap(ctx.mmPayload);
        _transferIn(ctx.collateral, address(ctx.box), amount);
        (, actualAmount) = spoke.supply(collateralReserveId, amount, address(this));
    }

    function _borrow(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        (ISpoke spoke,, uint256 debtReserveId) = AaveV4MMPayloadLib.unwrap(ctx.mmPayload);
        (, actualAmount) = spoke.borrow(debtReserveId, amount, address(this));
        _transferOut(ctx.debtAsset, address(ctx.box), actualAmount);
    }

    function _repay(MarketCtx memory ctx, uint256 amount, uint256 balanceBefore)
        internal
        virtual
        override
        returns (uint256 actualAmount)
    {
        (ISpoke spoke,, uint256 debtReserveId) = AaveV4MMPayloadLib.unwrap(ctx.mmPayload);
        actualAmount = PMath.min(amount, balanceBefore);
        if (actualAmount > 0) {
            _transferFrom(IERC20(ctx.debtAsset), address(ctx.box), address(this), actualAmount);
            (, actualAmount) = spoke.repay(debtReserveId, actualAmount, address(this));
        }
    }

    function _withdraw(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        (ISpoke spoke, uint256 collateralReserveId,) = AaveV4MMPayloadLib.unwrap(ctx.mmPayload);
        (, actualAmount) = spoke.withdraw(collateralReserveId, amount, address(this));
        _transferOut(ctx.collateral, address(ctx.box), actualAmount);
    }

    function oraclePtDebtRate(MarketCtx memory ctx) public view override returns (uint256) {
        (ISpoke spoke, uint256 collateralReserveId, uint256 debtReserveId) = AaveV4MMPayloadLib.unwrap(ctx.mmPayload);
        IAaveOracle oracle = IAaveOracle(spoke.ORACLE());

        uint256 ptPrice = oracle.getReservePrice(collateralReserveId);
        uint256 debtPrice = oracle.getReservePrice(debtReserveId);

        return ptPrice * PMath.ONE * 10 ** IERC20(ctx.debtAsset).decimals()
            / (debtPrice * 10 ** IERC20(ctx.collateral).decimals());
    }
}
