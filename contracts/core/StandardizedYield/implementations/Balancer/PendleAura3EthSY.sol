// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../interfaces/Balancer/IVault.sol";
import "../../../../interfaces/Balancer/IBasePool.sol";
import "./base/PendleAuraBalancerLPSY.sol";
import "./base/StableMath.sol";
import "./base/StablePoolUserData.sol";
import "./base/BalancerComposableStablePoolHelper.sol";
import "./base/BalancerPreviewComposableStablePoolHelper.sol";
import "./base/BalancerPreviewVaultHelper.sol";

contract PendleAura3EthSY is BalancerComposableStablePoolHelper {
    using SafeERC20 for IERC20;
    using BalancerPreviewVaultHelper for bytes32;

    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant BPT = 0x8e85e97ed19C0fa13B2549309965291fbbc0048b;
    address public constant SFRXETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;

    uint256 internal constant AURA_PID = 13;
    address internal constant LP = 0x8e85e97ed19C0fa13B2549309965291fbbc0048b;
    bytes32 internal constant POOL_ID =
        0x8e85e97ed19c0fa13b2549309965291fbbc0048b0000000000000000000003ba;

    constructor(
        string memory _name,
        string memory _symbol
    ) PendleAuraBalancerLPSY(_name, _symbol, LP, AURA_PID) {}

    function _getPoolTokenAddresses()
        internal
        view
        virtual
        override
        returns (address[] memory res)
    {
        res = new address[](4);
        res[0] = WSTETH;
        res[1] = BPT;
        res[2] = SFRXETH;
        res[3] = RETH;
    }

    function getTokensIn() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = WSTETH;
        res[1] = BPT;
        res[2] = SFRXETH;
        res[3] = RETH;
    }

    function getTokensOut() public view virtual override returns (address[] memory res) {
        res = new address[](4);
        res[0] = WSTETH;
        res[1] = BPT;
        res[2] = SFRXETH;
        res[3] = RETH;
    }

    function isValidTokenIn(address token) public view virtual override returns (bool) {
        return (token == WSTETH || token == BPT || token == SFRXETH || token == RETH);
    }

    function isValidTokenOut(address token) public view virtual override returns (bool) {
        return (token == WSTETH || token == BPT || token == SFRXETH || token == RETH);
    }

    function exchangeRate() public view virtual override returns (uint256) {
        return BalancerPreviewComposableStablePoolHelper.getVirtualPrice();
    }

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT/JOIN
    //////////////////////////////////////////////////////////////*/

    function _depositToBalancerSingleToken(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal virtual override returns (uint256) {
        uint256 balanceBefore = IERC20(balancerLp).balanceOf(address(this));

        // transfer directly to the vault to use internal balance
        IVault.JoinPoolRequest memory request = _assembleJoinRequest(
            tokenIn,
            amountTokenToDeposit
        );

        IERC20(tokenIn).safeTransfer(BALANCER_VAULT, amountTokenToDeposit);
        IVault(BALANCER_VAULT).joinPool(balancerPoolId, address(this), address(this), request);

        // calculate shares received and return
        uint256 balanceAfter = IERC20(balancerLp).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    function _previewDepositToBalancerSingleToken(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountLpOut) {
        IVault.JoinPoolRequest memory request = _assembleJoinRequest(
            tokenIn,
            amountTokenToDeposit
        );
        amountLpOut = balancerPoolId.joinPoolPreview(address(this), address(this), request);
    }

    /*///////////////////////////////////////////////////////////////
                    REDEEM/EXIT
    //////////////////////////////////////////////////////////////*/

    function _redeemFromBalancerSingleToken(
        address receiver,
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal virtual override returns (uint256) {
        IVault.ExitPoolRequest memory request = _assembleExitRequest(tokenOut, amountLpToRedeem);

        IVault(BALANCER_VAULT).exitPool(balancerPoolId, address(this), payable(receiver), request);

        // tokens received = tokens out
        return IERC20(tokenOut).balanceOf(address(this));
    }

    function _previewRedeemFromBalancerSingleToken(
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal view virtual override returns (uint256 amountTokenOut) {
        IVault.ExitPoolRequest memory request = _assembleExitRequest(tokenOut, amountLpToRedeem);

        amountTokenOut = balancerPoolId.exitPoolPreview(address(this), address(this), request);
    }
}
