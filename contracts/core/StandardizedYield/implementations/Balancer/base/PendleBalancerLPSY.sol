// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../SYBaseWithRewards.sol";
import "../../../../../interfaces/Balancer/ILiquidityGaugeFactory.sol";
import "../../../../../interfaces/Balancer/IGauge.sol";
import "../../../../../interfaces/Balancer/IVault.sol";
import "../../../../../interfaces/Balancer/IAsset.sol";
import "../../../../../interfaces/Balancer/IBasePool.sol";
import "../../../../../interfaces/ConvexCurve/IBooster.sol";
import "../../../../../interfaces/ConvexCurve/IRewards.sol";
import "../../../../libraries/ArrayLib.sol";

abstract contract PendleBalancerLPSY is SYBaseWithRewards {
    using SafeERC20 for IERC20;
    using ArrayLib for address[];

    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public constant BALANCER_GAUGE_FACTORY = 0x4E7bBd911cf1EFa442BC1b2e9Ea01ffE785412EC;
    address public constant BAL_TOKEN = 0xba100000625a3754423978a60c9317c58a424e3D;
    address public constant AURA_BOOSTER = 0xA57b8d98dAE62B26Ec3bcC4a365338157060B234;
    address public constant AURA_TOKEN = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;

    address public immutable balancerLp;
    bytes32 public immutable balancerPoolId;
    uint256 public immutable auraPid;
    address public immutable auraRewardManager;

    constructor(
        string memory _name,
        string memory _symbol,
        address _balancerLp,
        uint256 _auraPid
    ) SYBaseWithRewards(_name, _symbol, _balancerLp) {
        balancerPoolId = IBasePool(_balancerLp).getPoolId();
        auraPid = _auraPid;

        (balancerLp, auraRewardManager) = _getPoolInfo(_auraPid);
        if (balancerLp != _balancerLp) revert Errors.SYBalancerInvalidPid();

        address[] memory tokens = _getPoolTokens();
        for (uint i = 0; i < tokens.length; ++i) {
            _safeApproveInf(tokens[i], BALANCER_VAULT);
        }
        _safeApproveInf(_balancerLp, AURA_BOOSTER);
    }

    function _getPoolInfo(
        uint256 _auraPid
    ) internal view returns (address _auraLp, address _auraRewardManager) {
        if (_auraPid > IBooster(AURA_BOOSTER).poolLength()) revert Errors.SYBalancerInvalidPid();

        (_auraLp, , , _auraRewardManager, , ) = IBooster(AURA_BOOSTER).poolInfo(_auraPid);
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

        IBooster(AURA_BOOSTER).deposit(auraPid, amountSharesOut, true);
    }

    /**
     * @notice Either unwraps LP, or also exits pool using exact LP for only `tokenOut`
     */
    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        IRewards(auraRewardManager).withdrawAndUnwrap(amountSharesToRedeem, false);

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
    function exchangeRate() public view virtual override returns (uint256) {
        // TODO
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function _getRewardTokens() internal view virtual override returns (address[] memory res) {
        res = new address[](2);
        res[0] = BAL_TOKEN;
        res[1] = AURA_TOKEN;
    }

    function _redeemExternalReward() internal virtual override {
        IRewards(auraRewardManager).getReward();
    }

    /*///////////////////////////////////////////////////////////////
                    MISC FUNCTIONS FOR METADATA
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev this is made abstract because getPoolTokens() for the WSTETH-RETH-FRXETH pool also
     * returns the BPT itself along with the three pool tokens. This is not the case for most other
     * Balancer pools.
     */
    function getTokensIn() public view virtual override returns (address[] memory res);

    function getTokensOut() public view virtual override returns (address[] memory res);

    function _getPoolTokens() internal view virtual returns (address[] memory res) {
        IERC20[] memory tokens;
        (tokens, , ) = IVault(BALANCER_VAULT).getPoolTokens(balancerPoolId);

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
