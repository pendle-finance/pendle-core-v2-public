//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAaveRewardsController} from "./dependencies/IAaveRewardsController.sol";
import {IPool} from "./dependencies/IPool.sol";
import {IPoolAddressesProvider} from "./dependencies/IPoolAddressesProvider.sol";
import {IPoolDataProviderV3} from "./dependencies/IPoolDataProviderV3.sol";
import {IAaveOracle} from "./dependencies/IAaveOracle.sol";
import {AaveDataTypes} from "./dependencies/AaveDataTypes.sol";

import {IPLoopPositionBox, BoxData} from "../../../../interfaces/IPLoopPositionBox.sol";
import {PMath} from "../../../../core/libraries/math/PMath.sol";
import {BaseMoneyMarketView, Reward} from "../../BaseMoneyMarketView.sol";
import {AaveMMPayloadLib} from "./AaveMMPayloadLib.sol";
import {TokenHelper} from "../../../../core/libraries/TokenHelper.sol";

contract AaveMoneyMarketView is BaseMoneyMarketView, TokenHelper {
    using PMath for uint256;

    uint256 internal constant RAY = 1e27;
    /// @dev Aave returns LTV / liquidation thresholds in bps (×1e4); scale to WAD (×1e18).
    uint256 internal constant BPS_TO_WAD = 1e14;
    /// @dev Aave returns *annualized* reserve rates in RAY (×1e27); scale to WAD (÷1e9). `_rates`
    /// then feeds the annual WAD rate to `_apy` with `perSeconds = 365 days` for compounding.
    uint256 internal constant RAY_TO_WAD = 1e9;

    IPoolAddressesProvider public immutable poolAddressesProvider;
    IAaveRewardsController public immutable rewardsController;

    constructor(
        string memory _moneyMarketName,
        address _ptLooper,
        address _poolAddressesProvider,
        address _rewardsController
    ) BaseMoneyMarketView(_moneyMarketName, _ptLooper) {
        poolAddressesProvider = IPoolAddressesProvider(_poolAddressesProvider);
        rewardsController = IAaveRewardsController(_rewardsController);
    }

    function pool() public view virtual returns (IPool) {
        return poolAddressesProvider.getPool();
    }

    function dataProvider() public view virtual returns (IPoolDataProviderV3) {
        return poolAddressesProvider.getPoolDataProvider();
    }

    function oracle() public view virtual returns (IAaveOracle) {
        return poolAddressesProvider.getPriceOracle();
    }

    // ========== IMoneyMarketView ==========

    function _moneyMarketBalances(IPLoopPositionBox box, BoxData memory bd)
        internal
        virtual
        override
        returns (uint256 mmPtBalance, uint256 mmDebtBalance)
    {
        address account = box.SPOKE_MONEY_MARKET();
        IPoolDataProviderV3 dp = dataProvider();
        (mmPtBalance,,,,,,,,) = dp.getUserReserveData(bd.spokePt, account);
        (,, mmDebtBalance,,,,,,) = dp.getUserReserveData(bd.spokeDebtToken, account);
    }

    function _thresholds(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 ltv, uint256 liquidationThreshold)
    {
        (uint8 eModeCategoryId,) = AaveMMPayloadLib.unwrap(bd.mmPayload);

        if (eModeCategoryId == 0) {
            (, ltv, liquidationThreshold,,,,,,,) = dataProvider().getReserveConfigurationData(bd.spokePt);
        } else {
            (, ltv, liquidationThreshold) = pool().getEModeCategoryData(eModeCategoryId);
        }

        ltv *= BPS_TO_WAD;
        liquidationThreshold *= BPS_TO_WAD;
    }

    function _liquidity(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        IPoolDataProviderV3 dp = dataProvider();
        IPool _pool = pool();
        AaveDataTypes.ReserveData memory prd = _pool.getReserveData(IERC20(bd.spokePt));

        // calculate lending
        {
            (, uint256 supplyCap) = _getScaledReserveCap(dp, bd.spokePt);
            if (supplyCap == 0) {
                lending = IERC20(bd.spokePt).totalSupply(); // Infinite supply cap
            } else {
                uint256 currentSupply = (prd.aTokenAddress.scaledTotalSupply() + prd.accruedToTreasury)
                    * _pool.getReserveNormalizedIncome(IERC20(bd.spokePt)) / RAY;
                lending = supplyCap.subMax0(currentSupply);
            }
        }

        // calculate borrowing
        {
            (uint256 borrowCap,) = _getScaledReserveCap(dp, bd.spokeDebtToken);
            uint256 maxBorrowable =
                borrowCap == 0 ? type(uint256).max : borrowCap.subMax0(dp.getTotalDebt(bd.spokeDebtToken));

            borrowing = PMath.min(maxBorrowable, dp.getVirtualUnderlyingBalance(bd.spokeDebtToken));

            uint256 debtCeiling = dp.getDebtCeiling(bd.spokePt);
            if (debtCeiling > 0) {
                IAaveOracle _oracle = oracle();
                require(address(_oracle.BASE_CURRENCY()) == address(0), "Oracle base currency must be USD");

                uint256 unscaledAvail = debtCeiling - prd.isolationModeTotalDebt;
                uint256 available = unscaledAvail * _oracle.BASE_CURRENCY_UNIT() / (10 ** dp.getDebtCeilingDecimals());
                uint256 debtPrice = _oracle.getAssetPrice(IERC20(bd.spokeDebtToken));
                borrowing = PMath.min(borrowing, available * 10 ** IERC20(bd.spokeDebtToken).decimals() / debtPrice);
            }
        }
    }

    function _rates(IPLoopPositionBox, BoxData memory bd)
        internal
        view
        virtual
        override
        returns (uint256 borrowing, uint256 lending)
    {
        IPool _pool = pool();
        borrowing = _apy({
            rate: _pool.getReserveData(IERC20(bd.spokeDebtToken)).currentVariableBorrowRate / RAY_TO_WAD,
            perSeconds: 365 days
        });
        lending = _apy({ //
            rate: _pool.getReserveData(IERC20(bd.spokePt)).currentLiquidityRate / RAY_TO_WAD,
            perSeconds: 365 days
        });
    }

    function _rewards(IPLoopPositionBox box, BoxData memory bd)
        internal
        virtual
        override
        returns (Reward[] memory borrowing, Reward[] memory lending)
    {
        if (address(rewardsController) != address(0)) {
            address account = box.SPOKE_MONEY_MARKET();
            borrowing = _asRewards(account, bd.spokeDebtToken, true);
            lending = _asRewards(account, bd.spokePt, false);
        }
    }

    // ========== Internal helpers ==========

    function _asRewards(address account, address underlying, bool borrowing)
        internal
        view
        returns (Reward[] memory res)
    {
        (address aTokenAddress,, address variableDebtTokenAddress) =
            dataProvider().getReserveTokensAddresses(underlying);
        address asset = borrowing ? variableDebtTokenAddress : aTokenAddress;

        address[] memory assetArr = new address[](1);
        assetArr[0] = asset;

        address[] memory rewardTokens = rewardsController.getRewardsByAsset(asset);
        res = new Reward[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            res[i].token = rewardTokens[i];
            res[i].claimable = rewardsController.getUserRewards(assetArr, account, rewardTokens[i]);
        }
    }

    function _getScaledReserveCap(IPoolDataProviderV3 dp, address asset)
        internal
        view
        virtual
        returns (
            uint256, /* borrowCap */
            uint256 /* supplyCap */
        )
    {
        (uint256 borrowCap, uint256 supplyCap) = dp.getReserveCaps(asset);
        if (borrowCap == 0 && supplyCap == 0) return (0, 0);

        uint256 scale = 10 ** IERC20(asset).decimals();
        return (borrowCap * scale, supplyCap * scale);
    }
}
