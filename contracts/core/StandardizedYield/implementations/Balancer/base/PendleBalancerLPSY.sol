// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../SYBaseWithRewards.sol";
import "../../../../../interfaces/Balancer/ILiquidityGaugeFactory.sol";
import "../../../../../interfaces/Balancer/IGauge.sol";
import "../../../../../interfaces/Balancer/IVault.sol";
import "../../../../../interfaces/Balancer/IAsset.sol";
import "../../../../../interfaces/Balancer/IBasePool.sol";
import "../../../../libraries/ArrayLib.sol";

abstract contract PendleBalancerLPSY is SYBaseWithRewards {
    using SafeERC20 for IERC20;
    using ArrayLib for address[];

    address public constant VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public constant GAUGE_FACTORY = 0x4E7bBd911cf1EFa442BC1b2e9Ea01ffE785412EC;
    address public constant BAL_TOKEN = 0xba100000625a3754423978a60c9317c58a424e3D;
    address public immutable balancerLp;
    bytes32 public immutable poolId;

    constructor(
        string memory _name,
        string memory _symbol,
        address _balancerLp
    ) SYBaseWithRewards(_name, _symbol, _balancerLp) {
        balancerLp = _balancerLp;
        poolId = IBasePool(_balancerLp).getPoolId();

        address[] memory tokens = _getPoolTokens();
        for (uint i = 0; i < tokens.length; ++i) {
            _safeApproveInf(tokens[i], VAULT);
        }
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Either wraps LP, or also joins pool using exact tokenIn
     */
    function _deposit(
        address tokenIn,
        uint256 amount
    ) internal virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == balancerLp) {
            amountSharesOut = amount;
        } else {
            amountSharesOut = _depositToBalancerSingleToken(tokenIn, amount);
        }
    }

    /**
     * @notice Either unwraps LP, or also exits pool using exact LP for only `tokenOut`
     */
    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        if (tokenOut == balancerLp) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            amountTokenOut = _redeemFromBalancerSingleToken(tokenOut, amountSharesToRedeem);
        }
        _transferOut(tokenOut, receiver, amountTokenOut);
    }

    /*///////////////////////////////////////////////////////////////
                               EXCHANGE-RATE
    //////////////////////////////////////////////////////////////*/

    /**
     * 
     */
    function exchangeRate() public view virtual override returns (uint256) {}

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _getRewardTokens() internal view virtual override returns (address[] memory res) {
        address gauge = ILiquidityGaugeFactory(GAUGE_FACTORY).getPoolGauge(balancerLp);
        uint256 len = IGauge(gauge).reward_count();

        res = new address[](len+1);
        for (uint i = 0; i < len; i++) {
            res[i+1] = IGauge(gauge).reward_tokens(i);
        }
        res[0] = BAL_TOKEN;
    }

    function _redeemExternalReward() internal virtual override {
        // Redeem all extra rewards from the balancer pool
        address gauge = ILiquidityGaugeFactory(GAUGE_FACTORY).getPoolGauge(balancerLp);
        IGauge(gauge).claim_rewards(address(this), address(this));
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    function getTokensIn() public view virtual override returns (address[] memory res) {
        address[] memory tokens = _getPoolTokens();

        res = new address[](tokens.length + 1);
        for (uint i = 0; i < tokens.length; ++i) {
            res[i] = address(tokens[i]);
        }
        res[tokens.length] = balancerLp;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        address[] memory tokens = _getPoolTokens();

        res = new address[](tokens.length + 1);
        for (uint i = 0; i < tokens.length; ++i) {
            res[i] = address(tokens[i]);
        }
        res[tokens.length] = balancerLp;
    }

    function _getPoolTokens() internal view virtual returns (address[] memory res) {
        IERC20[] memory tokens;
        (tokens, , ) = IVault(VAULT).getPoolTokens(poolId);

        res = new address[](tokens.length);
        for (uint i = 0; i < tokens.length; ++i) {
            res[i] = address(tokens[i]);
        }
    }

    function _previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountSharesOut) {
        if (tokenIn == balancerLp) {
            amountSharesOut = amountTokenToDeposit;
        } else {
            amountSharesOut = _previewDepositToBalancerSingleToken(tokenIn, amountTokenToDeposit);
        }
    }

    function _previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal view virtual override returns (uint256 amountTokenOut) {
        if (tokenOut == balancerLp) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            amountTokenOut = _previewRedeemFromBalancerSingleToken(tokenOut, amountSharesToRedeem);
        }
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        address[] memory tokensIn = getTokensIn();
        return tokensIn.contains(token);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        address[] memory tokensIn = getTokensOut();
        return tokensIn.contains(token);
    }

    function _depositToBalancerSingleToken(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal virtual returns (uint256);

    function _redeemFromBalancerSingleToken(
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal virtual returns (uint256);

    function _previewDepositToBalancerSingleToken(
        address token,
        uint256 amountTokenToDeposit
    ) internal view virtual returns (uint256 amountLpOut);

    function _previewRedeemFromBalancerSingleToken(
        address token,
        uint256 amountLpToRedeem
    ) internal view virtual returns (uint256 amountTokenOut);

    function assetInfo()
        external
        view
        returns (AssetType assetType, address assetAddress, uint8 assetDecimals)
    {
        return (AssetType.LIQUIDITY, balancerLp, IERC20Metadata(balancerLp).decimals());
    }
}
