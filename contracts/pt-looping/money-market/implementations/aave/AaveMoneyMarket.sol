//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IPool} from "./dependencies/IPool.sol";
import {IPoolAddressesProvider} from "./dependencies/IPoolAddressesProvider.sol";
import {AaveDataTypes} from "./dependencies/AaveDataTypes.sol";
import {IAaveOracle} from "./dependencies/IAaveOracle.sol";

import {MarketCtx} from "../../../../interfaces/IMoneyMarket.sol";
import {BaseMoneyMarket} from "../../BaseMoneyMarket.sol";
import {AaveMMPayloadLib} from "./AaveMMPayloadLib.sol";
import {PMath} from "../../../../core/libraries/math/PMath.sol";

contract AaveMoneyMarket is BaseMoneyMarket {
    IPoolAddressesProvider public immutable poolAddressesProvider;

    constructor(address ptLooper, address _poolAddressesProvider) BaseMoneyMarket(ptLooper) {
        poolAddressesProvider = IPoolAddressesProvider(_poolAddressesProvider);
    }

    function pool() public view virtual returns (IPool) {
        return poolAddressesProvider.getPool();
    }

    function oracle() public view virtual returns (IAaveOracle) {
        return poolAddressesProvider.getPriceOracle();
    }

    // ========== IMoneyMarket ==========

    function _initialize(MarketCtx memory ctx) internal virtual override {
        IPool _pool = pool();

        (uint8 eModeCategoryId,) = AaveMMPayloadLib.unwrap(ctx.mmPayload);
        _pool.setUserEMode(eModeCategoryId);

        _safeApproveInf(ctx.collateral, address(_pool));
        _safeApproveInf(ctx.debtAsset, address(_pool));
    }

    function collateralBalance(MarketCtx memory ctx) public view override returns (uint256 balance) {
        return _aToken(pool(), ctx.collateral).balanceOf(address(this));
    }

    function debtBalance(MarketCtx memory ctx) public view override returns (uint256 balance) {
        return _vToken(pool(), ctx.debtAsset).balanceOf(address(this));
    }

    function _lend(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        IPool _pool = pool();
        address asset = ctx.collateral;
        _transferFrom(IERC20(asset), address(ctx.box), address(this), amount);
        _pool.supply({asset: asset, amount: amount, onBehalfOf: address(this), referralCode: 0});

        actualAmount = amount;

        (, bool isolationMode) = AaveMMPayloadLib.unwrap(ctx.mmPayload);
        if (isolationMode) {
            _pool.setUserUseReserveAsCollateral(asset, true);
        }
    }

    function _borrow(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        address asset = ctx.debtAsset;
        pool()
            .borrow({
            asset: asset,
            amount: amount,
            interestRateMode: uint8(AaveDataTypes.InterestRateMode.VARIABLE),
            onBehalfOf: address(this),
            referralCode: 0
        });

        _transferOut(asset, address(ctx.box), amount);
        actualAmount = amount;
    }

    function _repay(MarketCtx memory ctx, uint256 amount, uint256 balanceBefore)
        internal
        virtual
        override
        returns (uint256 actualAmount)
    {
        actualAmount = PMath.min(amount, balanceBefore);
        if (actualAmount > 0) {
            address asset = ctx.debtAsset;
            _transferFrom(IERC20(asset), address(ctx.box), address(this), actualAmount);
            actualAmount =
                pool().repay(asset, actualAmount, uint8(AaveDataTypes.InterestRateMode.VARIABLE), address(this));
        }
    }

    function _withdraw(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        actualAmount = pool().withdraw(ctx.collateral, amount, address(ctx.box));
    }

    function _aToken(IPool _pool, address asset) internal view virtual returns (IERC20) {
        return IERC20(_pool.getReserveData(IERC20(asset)).aTokenAddress);
    }

    function _vToken(IPool _pool, address asset) internal view virtual returns (IERC20) {
        return IERC20(_pool.getReserveData(IERC20(asset)).variableDebtTokenAddress);
    }

    /// @dev `mmPayload` unused: Aave's price oracle is queried directly by asset address.
    function oraclePtDebtRate(MarketCtx memory ctx) public view override returns (uint256) {
        IAaveOracle _oracle = oracle();
        uint256 ptPrice = _oraclePrice(_oracle, ctx.collateral);
        uint256 debtPrice = _oraclePrice(_oracle, ctx.debtAsset);

        // Aave oracle: price of 1 whole token in USD (1e8 base), not per raw unit.
        return ptPrice * PMath.ONE * 10 ** IERC20(ctx.debtAsset).decimals()
            / (debtPrice * 10 ** IERC20(ctx.collateral).decimals());
    }

    // ========== Internal helpers ==========

    function _oraclePrice(IAaveOracle _oracle, address asset) internal view virtual returns (uint256) {
        return _oracle.getAssetPrice(IERC20(asset));
    }
}
