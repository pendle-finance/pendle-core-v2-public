// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../../interfaces/Balancer/IVault.sol";
import "../../../../../interfaces/Balancer/IBalancerFees.sol";
import "../../../../../interfaces/Balancer/IBalancerStablePreview.sol";

abstract contract VaultPreview is IBalancerStablePreview {
    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    enum PoolBalanceChangeKind {
        JOIN,
        EXIT
    }

    struct PoolBalanceChange {
        IAsset[] assets;
        uint256[] limits;
        bytes userData;
        bool useInternalBalance;
    }

    address public immutable protocolFeesCollector;

    constructor() {
        protocolFeesCollector = IVault(BALANCER_VAULT).getProtocolFeesCollector();
    }

    function joinPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.JoinPoolRequest memory request,
        StablePoolData calldata poolData
    ) external view returns (uint256 amountBptOut) {
        amountBptOut = _joinOrExit(
            PoolBalanceChangeKind.JOIN,
            poolId,
            sender,
            payable(recipient),
            _toPoolBalanceChange(request),
            poolData
        );
    }

    function exitPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.ExitPoolRequest memory request,
        StablePoolData calldata poolData
    ) external view returns (uint256 amountTokenOut) {
        amountTokenOut = _joinOrExit(
            PoolBalanceChangeKind.EXIT,
            poolId,
            sender,
            recipient,
            _toPoolBalanceChange(request),
            poolData
        );
    }

    function _joinOrExit(
        PoolBalanceChangeKind kind,
        bytes32 poolId,
        address sender,
        address recipient,
        PoolBalanceChange memory change,
        StablePoolData calldata poolData
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
            lastChangeBlock,
            poolData
        );
    }

    function _callPoolBalanceChange(
        PoolBalanceChangeKind kind,
        bytes32 poolId,
        address sender,
        address recipient,
        PoolBalanceChange memory change,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        StablePoolData calldata poolData
    ) private view returns (uint256 amountsChanged) {
        if (kind == PoolBalanceChangeKind.JOIN) {
            amountsChanged = onJoinPool(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                _getProtocolSwapFeePercentage(),
                change.userData,
                poolData
            );
        } else {
            amountsChanged = onExitPool(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                _getProtocolSwapFeePercentage(),
                change.userData,
                poolData
            );
        }
    }

    function _getProtocolSwapFeePercentage() private view returns (uint256) {
        return IBalancerFees(protocolFeesCollector).getSwapFeePercentage();
    }

    function _validateTokensAndGetBalances(
        bytes32 poolId,
        IERC20[] memory //expectedTokens
    ) private view returns (uint256[] memory, uint256) {
        (, uint256[] memory balances, uint256 lastChangeBlock) = IVault(BALANCER_VAULT)
            .getPoolTokens(poolId);
        return (balances, lastChangeBlock);
    }

    function _translateToIERC20(IAsset[] memory assets) internal pure returns (IERC20[] memory) {
        unchecked {
            IERC20[] memory tokens = new IERC20[](assets.length);
            for (uint256 i = 0; i < assets.length; ++i) {
                tokens[i] = _translateToIERC20(assets[i]);
            }
            return tokens;
        }
    }

    function _translateToIERC20(IAsset asset) internal pure returns (IERC20) {
        return address(asset) == address(0) ? IERC20(WETH) : IERC20(address(asset));
    }

    function _toPoolBalanceChange(IVault.JoinPoolRequest memory request)
        private
        pure
        returns (PoolBalanceChange memory change)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            change := request
        }
    }

    function _toPoolBalanceChange(IVault.ExitPoolRequest memory request)
        private
        pure
        returns (PoolBalanceChange memory change)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            change := request
        }
    }

    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData,
        StablePoolData calldata poolData
    ) internal view virtual returns (uint256 bptAmountOut);

    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData,
        StablePoolData calldata poolData
    ) internal view virtual returns (uint256 amountTokenOut);

    /*///////////////////////////////////////////////////////////////
                               Helpers functions
    //////////////////////////////////////////////////////////////*/

    function _hasRateProvider(StablePoolData memory data, uint256 index)
        internal
        pure
        returns (bool)
    {
        return address(data.rateProviders[index]) != address(0);
    }

    function _isTokenExemptFromYieldProtocolFee(StablePoolData memory data, uint256 index)
        internal
        pure
        returns (bool)
    {
        return data.isExemptFromYieldProtocolFee[index];
    }
}
