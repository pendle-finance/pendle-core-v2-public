// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PendleBalancerLPSY.sol";
import "../../../../../interfaces/Balancer/IVault.sol";

/**
 * @notice interfacing joins/exits for balancer's "common" pools including weighted and stable pool
 * @dev the preview functions are left abstract to accomodate specific pool maths in the future
 */
abstract contract PendleBalancerCommonPoolSY is PendleBalancerLPSY {
    using SafeERC20 for IERC20;

    constructor(
        string memory _name,
        string memory _symbol,
        address _balancerLp,
        uint256 _auraPid
    ) PendleBalancerLPSY(_name, _symbol, _balancerLp, _auraPid) {}

    /*///////////////////////////////////////////////////////////////
                    JOIN/EXIT
    //////////////////////////////////////////////////////////////*/

    function _depositToBalancerSingleToken(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal virtual override returns (uint256) {
        uint256 balanceBefore = IERC20(balancerLp).balanceOf(address(this));

        // prepare to deposit
        address[] memory assets = _getPoolTokens();
        uint256[] memory maxAmountsIn = new uint256[](assets.length);

        // encode user data
        uint256 joinKind = 1; // EXACT_TOKENS_IN_FOR_BPT_OUT
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
        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest(
            assets,
            maxAmountsIn,
            userData,
            true
        );

        // transfer directly to the vault to use internal balance
        IERC20(tokenIn).safeTransfer(BALANCER_VAULT, amountTokenToDeposit);
        
        IVault(BALANCER_VAULT).joinPool(poolId, address(this), address(this), request);

        // calculate shares received and return
        uint256 balanceAfter = IERC20(balancerLp).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    function _redeemFromBalancerSingleToken(
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal virtual override returns (uint256) {
        address[] memory assets = _getPoolTokens();
        uint256[] memory minAmountsOut = new uint256[](assets.length);

        // encode user data
        uint256 exitKind = 0; // EXACT_BPT_IN_FOR_ONE_TOKEN_OUT
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
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(
            assets,
            minAmountsOut,
            userData,
            false
        );

        IVault(BALANCER_VAULT).exitPool(poolId, address(this), payable(address(this)), request);

        // tokens received = tokens out
        return IERC20(tokenOut).balanceOf(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                    PREVIEWS
    //////////////////////////////////////////////////////////////*/

    function _previewDepositToBalancerSingleToken(
        address token,
        uint256 amountTokenToDeposit
    ) internal view virtual override returns (uint256 amountLpOut);

    function _previewRedeemFromBalancerSingleToken(
        address token,
        uint256 amountLpToRedeem
    ) internal view virtual override returns (uint256 amountTokenOut);
}
