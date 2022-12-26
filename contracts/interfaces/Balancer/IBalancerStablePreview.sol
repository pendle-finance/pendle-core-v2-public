// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./IVault.sol";

interface IBalancerStablePreview {
    struct StablePoolData {
        address[] poolTokens;
        address[] rateProviders;
        uint256[] rawScalingFactors;
        bool[] isExemptFromYieldProtocolFee;
    }

    function LP() external view returns (address);

    function joinPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.JoinPoolRequest memory request,
        StablePoolData calldata poolData
    ) external view returns (uint256 amountBptOut);

    function exitPoolPreview(
        bytes32 poolId,
        address sender,
        address recipient,
        IVault.ExitPoolRequest memory request,
        StablePoolData calldata poolData
    ) external view returns (uint256 amountTokenOut);
}
