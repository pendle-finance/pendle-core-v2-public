// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FixedPoint.sol";
import "./StableMath.sol";
import "./StablePoolUserData.sol";
import "./BasePoolUserData.sol";
import "./PendleAuraBalancerLPSY.sol";
import "../../../../../interfaces/Balancer/IBasePool.sol";
import "../../../../../interfaces/Balancer/IVault.sol";
import "../../../../../interfaces/Balancer/IBalancerFees.sol";

abstract contract BalancerComposableStablePoolHelper is PendleAuraBalancerLPSY {
    using StablePoolUserData for bytes;
    using BasePoolUserData for bytes;

    function _assembleJoinRequest(
        address tokenIn,
        uint256 amountTokenToDeposit
    ) internal view virtual returns (IVault.JoinPoolRequest memory request) {
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

    function _assembleExitRequest(
        address tokenOut,
        uint256 amountLpToRedeem
    ) internal view virtual returns (IVault.ExitPoolRequest memory request) {
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

    /// @dev should return the same tokens as `IVault.getPoolTokens()`, hardcoded to save gas
    function _getPoolTokenAddresses() internal view virtual returns (address[] memory res);
}
