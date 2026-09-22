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

        uint8 eModeCategoryId = AaveMMPayloadLib.unwrap(ctx.mmPayload);
        _forceSetEModeAtInit(_pool, eModeCategoryId);

        _safeApproveInf(ctx.collateral, address(_pool));
        _safeApproveInf(ctx.debtAsset, address(_pool));
    }

    /// @notice Enters eMode, unset any pre-existing asset that is used as
    /// collateral if needed.
    /// @dev A counterfactual mm address can be funded by anyone before
    /// deployment, which can make the asset as collateral for the mm address.
    /// Such collateral that Aave flagged (LTV != 0 outside eMode, e.g. WETH)
    /// makes `setUserEMode` revert with InvalidCollateralInEmode.
    /// Therefore, we unset all collateral assets before setting EMode.
    function _forceSetEModeAtInit(IPool _pool, uint8 eModeCategoryId) internal {
        // https://github.com/aave-dao/aave-v3-origin/blob/cff15de6d1271b0c800fc001f4aea4c263e8a597/src/contracts/protocol/libraries/logic/ValidationLogic.sol#L448
        // We use the similar shortcut as Aave for happy case (do nothing if no bit is set in userConfBitmap)
        uint256 userConfBitmap = _pool.getUserConfiguration(address(this)).data;
        for (uint16 id = 0; userConfBitmap != 0; (id, userConfBitmap) = (id + 1, userConfBitmap >> 2)) {
            bool isUsingAsCollat = (userConfBitmap & 2) != 0;
            if (isUsingAsCollat) _pool.setUserUseReserveAsCollateral(_pool.getReserveAddressById(id), false);
        }

        _pool.setUserEMode(eModeCategoryId);
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

        _pool.setUserUseReserveAsCollateral(asset, true);
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
        return IERC20(_pool.getReserveAToken(asset));
    }

    function _vToken(IPool _pool, address asset) internal view virtual returns (IERC20) {
        return IERC20(_pool.getReserveVariableDebtToken(asset));
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
