// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FixedPoint.sol";
import "./StableMath.sol";
import "./StablePoolUserData.sol";
import "./BasePoolUserData.sol";
import "./BalancerPreviewComposableStablePoolHelper.sol";
import "../../../../../interfaces/Balancer/IBasePool.sol";
import "../../../../../interfaces/Balancer/IVault.sol";
import "../../../../../interfaces/Balancer/IBalancerFees.sol";

library BalancerPreviewVaultHelper {
    using BalancerPreviewComposableStablePoolHelper for bytes32;

    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    struct PoolBalanceChange {
        IAsset[] assets;
        uint256[] limits;
        bytes userData;
        bool useInternalBalance;
    }

    function joinPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.JoinPoolRequest memory request
    ) internal view returns (uint256 amountBptOut) {
        (address LP,) = IVault(BALANCER_VAULT).getPool(poolId);

        (bool paused, , ) = IBasePool(LP).getPausedState();
        require(!paused, "Pool is paused");

        amountBptOut = _joinOrExit(0, poolId, sender, recipient, _toPoolBalanceChange(request));
    }

    function exitPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.ExitPoolRequest memory request
    ) internal view returns (uint256 amountTokenOut) {
        amountTokenOut = _joinOrExit(1, poolId, sender, recipient, _toPoolBalanceChange(request));
    }

    function _joinOrExit(
        uint256 kind,
        bytes32 poolId,
        address sender,
        address recipient,
        PoolBalanceChange memory change
    ) private view returns (uint256 amountBptOrTokensOut) {
        IERC20[] memory tokens = _translateToIERC20(change.assets);
        (uint256[] memory balances, uint256 lastChangeBlock) = _validateTokensAndGetBalances(
            poolId,
            tokens
        );

        amountBptOrTokensOut = _callPoolBalanceChange(
            kind,
            poolId,
            sender,
            recipient,
            change,
            balances,
            lastChangeBlock
        );
    }

    function _callPoolBalanceChange(
        uint256 kind,
        bytes32 poolId,
        address sender,
        address recipient,
        PoolBalanceChange memory change,
        uint256[] memory balances,
        uint256 lastChangeBlock
    ) private view returns (uint256 amountsChanged) {
        if (kind == 0) {
            amountsChanged = poolId.onJoinPoolPreview(
                sender,
                recipient,
                balances,
                lastChangeBlock,
                _getProtocolSwapFeePercentage(),
                change.userData
            );
        } else {
            amountsChanged = poolId.onExitPoolPreview(
                sender,
                recipient,
                balances,
                lastChangeBlock,
                _getProtocolSwapFeePercentage(),
                change.userData
            );
        }
    }

    function _getProtocolSwapFeePercentage() private view returns (uint256) {
        address collector = IVault(BALANCER_VAULT).getProtocolFeesCollector();
        return IBalancerFees(collector).getSwapFeePercentage();
    }

    function _validateTokensAndGetBalances(
        bytes32 poolId,
        IERC20[] memory //expectedTokens
    ) private view returns (uint256[] memory, uint256) {
        (
            ,
            uint256[] memory balances,
            uint256 lastChangeBlock
        ) = IVault(BALANCER_VAULT).getPoolTokens(poolId);
        return (balances, lastChangeBlock);
    }

    function _translateToIERC20(IAsset[] memory assets) internal view returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](assets.length);
        for (uint256 i = 0; i < assets.length; ++i) {
            tokens[i] = _translateToIERC20(assets[i]);
        }
        return tokens;
    }

    function _translateToIERC20(IAsset asset) internal view returns (IERC20) {
        return
            address(asset) == address(0) ? IVault(BALANCER_VAULT).WETH() : IERC20(address(asset));
    }

    function _toPoolBalanceChange(
        IVault.JoinPoolRequest memory request
    ) private pure returns (PoolBalanceChange memory change) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            change := request
        }
    }

    function _toPoolBalanceChange(
        IVault.ExitPoolRequest memory request
    ) private pure returns (PoolBalanceChange memory change) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            change := request
        }
    }
}