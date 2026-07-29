//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IEVC} from "./dependencies/IEthereumVaultConnector.sol";
import {IEulerVault} from "./dependencies/IEulerVault.sol";
import {IEulerPriceOracle} from "./dependencies/IEulerPriceOracle.sol";
import {IEulerFactory} from "./dependencies/IEulerFactory.sol";

import {MarketCtx} from "../../../../interfaces/IMoneyMarket.sol";
import {BaseMoneyMarket} from "../../BaseMoneyMarket.sol";
import {EulerMMPayloadLib} from "./EulerMMPayloadLib.sol";
import {PMath} from "../../../../core/libraries/math/PMath.sol";

contract EulerMoneyMarket is BaseMoneyMarket {
    using PMath for uint256;
    using EulerMMPayloadLib for IEulerFactory;

    IEVC public immutable EVC;
    IEulerFactory public immutable FACTORY;

    constructor(address ptLooper, address _evc, address _factory) BaseMoneyMarket(ptLooper) {
        EVC = IEVC(_evc);
        FACTORY = IEulerFactory(_factory);
    }

    function _initialize(MarketCtx memory ctx) internal virtual override {
        IEulerVault baseVault = FACTORY.baseVault(ctx.mmPayload);
        IEulerVault quoteVault = FACTORY.quoteVault(ctx.mmPayload);
        require(baseVault.asset() == ctx.collateral, "EulerMoneyMarket: base vault asset mismatch");
        require(quoteVault.asset() == ctx.debtAsset, "EulerMoneyMarket: quote vault asset mismatch");

        _safeApproveInf(ctx.collateral, address(baseVault));
        _safeApproveInf(ctx.debtAsset, address(quoteVault));

        EVC.enableCollateral(address(this), address(baseVault));
        EVC.enableController(address(this), address(quoteVault));

        // Opt in to reward-stream balance tracking on the collateral (PT) vault.
        // No-op if the vault has no active reward streams.
        // Cheap to always call.
        baseVault.enableBalanceForwarder();
    }

    /// @dev Function is view, it already reflects accrued interest.
    function collateralBalance(MarketCtx memory ctx) public view override returns (uint256 balance) {
        IEulerVault baseVault = FACTORY.baseVault(ctx.mmPayload);
        return baseVault.convertToAssets(baseVault.balanceOf(address(this)));
    }

    /// @dev Function is view, it already reflects accrued interest.
    function debtBalance(MarketCtx memory ctx) public view override returns (uint256 balance) {
        return FACTORY.quoteVault(ctx.mmPayload).debtOf(address(this));
    }

    function _lend(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        _transferIn(ctx.collateral, address(ctx.box), amount);
        IEulerVault baseVault = FACTORY.baseVault(ctx.mmPayload);
        uint256 shares = baseVault.deposit(amount, address(this));
        actualAmount = baseVault.convertToAssets(shares);
    }

    function _borrow(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        actualAmount = FACTORY.quoteVault(ctx.mmPayload).borrow(amount, address(ctx.box));
    }

    function _repay(MarketCtx memory ctx, uint256 amount, uint256 balanceBefore)
        internal
        virtual
        override
        returns (uint256 actualAmount)
    {
        actualAmount = PMath.min(amount, balanceBefore);
        if (actualAmount > 0) {
            _transferFrom(IERC20(ctx.debtAsset), address(ctx.box), address(this), actualAmount);
            actualAmount = FACTORY.quoteVault(ctx.mmPayload).repay(actualAmount, address(this));
        }
    }

    function _withdraw(MarketCtx memory ctx, uint256 amount) internal virtual override returns (uint256 actualAmount) {
        IEulerVault baseVault = FACTORY.baseVault(ctx.mmPayload);
        baseVault.withdraw(amount, address(ctx.box), address(this));
        actualAmount = amount;
    }

    /// @notice Sourced both PT and debt price from the debt (quote) vault's oracle and unitOfAccount,
    /// because quote vault is the CONTROLLER vault, and Euler's price oracle is scoped per controller vault,
    /// not global per asset.
    /// Therefore the quote vault is the canonical price source.
    function oraclePtDebtRate(MarketCtx memory ctx) public view override returns (uint256) {
        IEulerVault controllerVault = FACTORY.quoteVault(ctx.mmPayload);
        IEulerPriceOracle oracle = controllerVault.oracle();
        address unit = controllerVault.unitOfAccount();

        uint256 collatUnit = 10 ** IERC20(ctx.collateral).decimals();
        uint256 debtUnit = 10 ** IERC20(ctx.debtAsset).decimals();

        uint256 ptPrice = oracle.getQuote(collatUnit, ctx.collateral, unit);
        uint256 debtPrice = oracle.getQuote(debtUnit, ctx.debtAsset, unit);

        return (ptPrice * debtUnit).divDown(debtPrice * collatUnit);
    }
}
