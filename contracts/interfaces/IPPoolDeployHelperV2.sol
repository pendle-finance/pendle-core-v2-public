// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPPoolDeployHelperV2 {
    struct PoolDeploymentParams {
        uint32 expiry;
        uint80 lnFeeRateRoot;
        int256 scalarRoot;
        int256 initialRateAnchor;
        bool doCacheIndexSameBlock;
    }

    struct PoolDeploymentAddrs {
        address SY;
        address PT;
        address YT;
        address market;
    }

    struct PoolConfig {
        uint32 expiry;
        uint256 rateMin;
        uint256 rateMax;
        uint256 desiredImpliedRate;
        uint256 fee;
    }

    event MarketDeployment(PoolDeploymentAddrs addrs, PoolDeploymentParams params);

    function deploy5115MarketAndSeedLiquidity(
        address SY,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed
    ) external payable returns (PoolDeploymentAddrs memory);
}
