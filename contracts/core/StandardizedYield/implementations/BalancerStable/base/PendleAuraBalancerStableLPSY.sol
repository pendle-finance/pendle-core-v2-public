// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../SYBaseWithRewards.sol";
import "../../../../../interfaces/Balancer/ILiquidityGaugeFactory.sol";
import "../../../../../interfaces/Balancer/IGauge.sol";
import "../../../../../interfaces/Balancer/IVault.sol";
import "../../../../../interfaces/Balancer/IAsset.sol";
import "../../../../../interfaces/Balancer/IBasePool.sol";
import "../../../../../interfaces/ConvexCurve/IBooster.sol";
import "../../../../../interfaces/ConvexCurve/IRewards.sol";
import "../../../../libraries/ArrayLib.sol";
import "./StablePreview.sol";

abstract contract PendleAuraBalancerStableLPSY is SYBaseWithRewards {
    using SafeERC20 for IERC20;
    using ArrayLib for address[];
    using StableMath for uint256;

    address public constant BAL_TOKEN = 0xba100000625a3754423978a60c9317c58a424e3D;
    address public constant AURA_TOKEN = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;
    address public constant AURA_BOOSTER = 0xA57b8d98dAE62B26Ec3bcC4a365338157060B234;
    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    address public immutable balLp;
    bytes32 public immutable balPoolId;
    uint256 public immutable auraPid;
    address public immutable auraRewardManager;
    StablePreview public immutable stablePreview;

    constructor(
        string memory _name,
        string memory _symbol,
        address _balLp,
        uint256 _auraPid,
        StablePreview _stablePreview
    ) SYBaseWithRewards(_name, _symbol, _balLp) {
        balPoolId = IBasePool(_balLp).getPoolId();
        auraPid = _auraPid;

        (balLp, auraRewardManager) = _getPoolInfo(_auraPid);
        if (balLp != _balLp) revert Errors.SYBalancerInvalidPid();

        _safeApproveInf(_balLp, AURA_BOOSTER);

        stablePreview = _stablePreview;
        assert(stablePreview.LP() == balLp && stablePreview.POOL_ID() == balPoolId);
    }

    function _getPoolInfo(uint256 _auraPid)
        internal
        view
        returns (address _auraLp, address _auraRewardManager)
    {
        if (_auraPid > IBooster(AURA_BOOSTER).poolLength()) revert Errors.SYBalancerInvalidPid();
        (_auraLp, , , _auraRewardManager, , ) = IBooster(AURA_BOOSTER).poolInfo(_auraPid);
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/REDEEM USING BASE TOKENS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Either wraps LP, or also joins pool using exact tokenIn
     */
    function _deposit(address tokenIn, uint256 amount)
        internal
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == balLp) {
            amountSharesOut = amount;
        } else {
            amountSharesOut = _depositToBalancer(tokenIn, amount);
        }

        IBooster(AURA_BOOSTER).deposit(auraPid, amountSharesOut, true);
    }

    /**
     * @notice Either unwraps LP, or also exits pool using exact LP for only `tokenOut`
     * @dev Redeems straight to receiver without
     */
    function _redeem(
        address receiver,
        address tokenOut,
        uint256 amountSharesToRedeem
    ) internal virtual override returns (uint256 amountTokenOut) {
        IRewards(auraRewardManager).withdrawAndUnwrap(amountSharesToRedeem, false);

        if (tokenOut == balLp) {
            amountTokenOut = amountSharesToRedeem;
            _transferOut(tokenOut, receiver, amountTokenOut);
        } else {
            amountTokenOut = _redeemFromBalancer(receiver, tokenOut, amountSharesToRedeem);
        }
    }

    function exchangeRate() external view override returns (uint256 res) {
        (uint256 currentAmp, , ) = IBasePool(balLp).getAmplificationParameter();
        (IERC20[] memory tokens, uint256[] memory balances, ) = IVault(BALANCER_VAULT)
            .getPoolTokens(balPoolId);
        balances = _dropBptItem(tokens, balances);

        uint256 D = currentAmp._calculateInvariant(balances);
        uint256 totalSupply = IBasePool(balLp).getActualSupply();

        return (D * 1e18) / totalSupply;
    }

    function _dropBptItem(IERC20[] memory tokens, uint256[] memory amounts)
        internal
        view
        returns (uint256[] memory)
    {
        unchecked {
            uint256[] memory amountsWithoutBpt = new uint256[](amounts.length - 1);
            uint256 last = 0;
            for (uint256 i = 0; i < amountsWithoutBpt.length; i++) {
                if (address(tokens[i]) == balLp) continue;
                amountsWithoutBpt[last] = amounts[i];
                last++;
            }

            return amountsWithoutBpt;
        }
    }

    /*///////////////////////////////////////////////////////////////
                    BALANCER-RELATED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _depositToBalancer(address tokenIn, uint256 amountTokenToDeposit)
        internal
        virtual
        returns (uint256)
    {
        uint256 balanceBefore = IERC20(balLp).balanceOf(address(this));

        // transfer directly to the vault to use internal balance
        IVault.JoinPoolRequest memory request = _assembleJoinRequest(
            tokenIn,
            amountTokenToDeposit
        );

        IERC20(tokenIn).safeTransfer(BALANCER_VAULT, amountTokenToDeposit);
        IVault(BALANCER_VAULT).joinPool(balPoolId, address(this), address(this), request);

        // calculate shares received and return
        uint256 balanceAfter = IERC20(balLp).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    function _assembleJoinRequest(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        returns (IVault.JoinPoolRequest memory request)
    {
        // max amounts in
        address[] memory assets = _getPoolTokenAddresses();
        uint256[] memory maxAmountsIn = new uint256[](assets.length);

        // encode user data
        StablePoolUserData.JoinKind joinKind = StablePoolUserData
            .JoinKind
            .EXACT_TOKENS_IN_FOR_BPT_OUT;
        uint256[] memory amountsIn = new uint256[](assets.length);
        uint256 minimumBPT = 0;
        for (uint256 i = 0; i < assets.length; ++i) {
            if (assets[i] == tokenIn) {
                amountsIn[i] = amountTokenToDeposit;
                break;
            }
        }
        bytes memory userData = abi.encode(joinKind, amountsIn, minimumBPT);

        // assemble joinpoolrequest
        request = IVault.JoinPoolRequest(assets, maxAmountsIn, userData, true);
    }

    function _redeemFromBalancer(
        address receiver,
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal virtual returns (uint256) {
        IVault.ExitPoolRequest memory request = _assembleExitRequest(tokenOut, amountLpToRedeem);

        IVault(BALANCER_VAULT).exitPool(balPoolId, address(this), payable(receiver), request);

        // tokens received = tokens out
        return IERC20(tokenOut).balanceOf(address(this));
    }

    function _assembleExitRequest(address tokenOut, uint256 amountLpToRedeem)
        internal
        view
        virtual
        returns (IVault.ExitPoolRequest memory request)
    {
        address[] memory assets = _getPoolTokenAddresses();
        uint256[] memory minAmountsOut = new uint256[](assets.length);

        // encode user data
        StablePoolUserData.ExitKind exitKind = StablePoolUserData
            .ExitKind
            .EXACT_BPT_IN_FOR_ONE_TOKEN_OUT;
        uint256 bptAmountIn = amountLpToRedeem;
        uint256 exitTokenIndex;
        for (uint256 i = 0; i < assets.length; ++i) {
            if (assets[i] == tokenOut) {
                exitTokenIndex = i;
                break;
            }
        }

        bytes memory userData = abi.encode(exitKind, bptAmountIn, exitTokenIndex);

        // assemble exitpoolrequest
        request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);
    }

    function _getPoolTokenAddresses() internal view virtual returns (address[] memory res);

    /*///////////////////////////////////////////////////////////////
                   PREVIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
        internal
        view
        virtual
        override
        returns (uint256 amountSharesOut)
    {
        if (tokenIn == balLp) {
            amountSharesOut = amountTokenToDeposit;
        } else {
            IVault.JoinPoolRequest memory request = _assembleJoinRequest(
                tokenIn,
                amountTokenToDeposit
            );
            amountSharesOut = stablePreview.joinPoolPreview(
                balPoolId,
                address(this),
                address(this),
                request
            );
        }
    }

    function _previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
        internal
        view
        virtual
        override
        returns (uint256 amountTokenOut)
    {
        if (tokenOut == balLp) {
            amountTokenOut = amountSharesToRedeem;
        } else {
            IVault.ExitPoolRequest memory request = _assembleExitRequest(
                tokenOut,
                amountSharesToRedeem
            );

            amountTokenOut = stablePreview.exitPoolPreview(
                balPoolId,
                address(this),
                address(this),
                request
            );
        }
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

    function getTokensIn() public view virtual override returns (address[] memory res);

    function getTokensOut() public view virtual override returns (address[] memory res);

    function isValidTokenIn(address token) public view virtual override returns (bool);

    function isValidTokenOut(address token) public view virtual override returns (bool);

    function assetInfo()
        external
        view
        returns (
            AssetType assetType,
            address assetAddress,
            uint8 assetDecimals
        )
    {
        return (AssetType.LIQUIDITY, balLp, IERC20Metadata(balLp).decimals());
    }
}
