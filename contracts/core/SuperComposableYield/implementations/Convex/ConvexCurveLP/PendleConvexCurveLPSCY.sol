// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../SCYBaseWithRewards.sol";
import "../../../../../interfaces/ConvexCurve/IBooster.sol";
import "../../../../../interfaces/ConvexCurve/IRewards.sol";
import "../../../../../interfaces/Curve/ICrvPool.sol";

abstract contract PendleConvexCurveLPSCY is SCYBaseWithRewards {
    using SafeERC20 for IERC20;

    uint256 public immutable pid;
    address public immutable booster;
    address public immutable baseRewards;
    address public immutable crvPool;

    address public immutable CRV;
    address public immutable CVX;
    address public immutable LP;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _pid,
        address _convexBooster,
        address _crvLpToken,
        address _cvx,
        address _baseCrvPool
    ) SCYBaseWithRewards(_name, _symbol, _crvLpToken) {
        pid = _pid;
        CVX = _cvx;
        crvPool = _baseCrvPool;

        booster = _convexBooster;

        (LP, baseRewards, CRV) = _getPoolInfo(pid);
        if (LP != _crvLpToken) revert Errors.SCYCurveInvalidPid();

        _safeApprove(LP, booster, type(uint256).max);
    }

    function _getPoolInfo(uint256 _pid)
        internal
        view
        returns (
            address lptoken,
            address crvRewards,
            address crv
        )
    {
        if (_pid > IBooster(booster).poolLength()) revert Errors.SCYCurveInvalidPid();

        (lptoken, , , crvRewards, , ) = IBooster(booster).poolInfo(_pid);
        crv = IBooster(booster).crv();
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * If any of the base pool tokens are deposited, it will first add liquidity to the curve pool and mint LP,
     * which will then be deposited into convex
     */
    function _deposit(address tokenIn, uint256 amount)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == LP) {
            IBooster(booster).deposit(pid, amount, true);
            amountSharesOut = amount;
        } else {
            uint256 prevLpBalance = _selfBalance(LP);
            _depositToCurve(tokenIn, amount);
            amountSharesOut = _selfBalance(LP) - prevLpBalance;

            // Deposit LP Token received into Convex Booster
            IBooster(booster).deposit(pid, amountSharesOut, true);
        }
    }

    /**
     * If any of the base curve pool tokens is specified as 'tokenOut',
     * it will redeem the corresponding liquidity the LP token represents via the prevailing exchange rate.
     */
    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        IRewards(baseRewards).withdrawAndUnwrap(amountSharesToRedeem, false);

        if (_isBaseToken(tokenOut)) {
            uint256 prevBal = _selfBalance(tokenOut);
            ICrvPool(crvPool).remove_liquidity_one_coin(
                amountSharesToRedeem,
                Math.Int128(_getBaseTokenIndex(tokenOut)),
                0
            );
            amountTokenOut = _selfBalance(tokenOut) - prevBal;
        } else {
            // 'tokenOut' is LP
            amountTokenOut = amountSharesToRedeem;
        }
        if (receiver != address(this)) _transferOut(tokenOut, receiver, amountTokenOut);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * The current price of the pool LP token relative to the underlying pool assets. Given as an integer with 1e18 precision.
     */
    function exchangeRate() public view virtual override returns (uint256) {
        return ICrvPool(crvPool).get_virtual_price();
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * Refer to currentExtraRewards array of reward tokens specific to the curve pool.
     * @dev We are aware that Convex might add or remove reward tokens, but also agreed that it was
     * not worth the complexity
     **/
    function _getRewardTokens() internal view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = CRV;
        res[1] = CVX;
    }

    function _redeemExternalReward() internal virtual override {
        // Redeem all extra rewards from the curve pool
        IRewards(baseRewards).getReward();
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == LP) {
            amountSharesOut = amountTokenToDeposit;
        } else {
            // Calculate expected amount of LpToken to receive
            amountSharesOut = _previewDepositToCurve(tokenIn, amountTokenToDeposit);
        }
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        uint256 amountLpTokenToReceive = (amountSharesToRedeem * exchangeRate()) / 1e18;

        if (tokenOut == LP) {
            amountTokenOut = amountLpTokenToReceive;
        } else {
            // If 'tokenOut' is a CrvBaseToken, withdraw liquidity from curvePool to return the base token back to user.
            amountTokenOut = ICrvPool(crvPool).calc_withdraw_one_coin(
                amountLpTokenToReceive,
                Math.Int128(_getBaseTokenIndex(tokenOut))
            );
        }
    }

    function getTokensIn() public view virtual override returns (address[] memory res);

    function getTokensOut() public view virtual override returns (address[] memory res);

    function isValidTokenIn(address token) public view virtual override returns (bool);

    function isValidTokenOut(address token) public view virtual override returns (bool);

    function _depositToCurve(address token, uint256 amount) internal virtual;

    function _previewDepositToCurve(address token, uint256 amount)
        internal
        view
        virtual
        returns (uint256 amountLpOut);

    function _getBaseTokenIndex(address crvBaseToken)
        internal
        view
        virtual
        returns (uint256 index);

    function _isBaseToken(address token) internal view virtual returns (bool res);

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.LIQUIDITY, LP, IERC20Metadata(LP).decimals());
    }
}
