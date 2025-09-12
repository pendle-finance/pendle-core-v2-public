// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPPoolDeployHelperV2.sol";

interface IPCommonPoolDeployHelperV2 is IPPoolDeployHelperV2 {
    function deployERC4626Market(
        bytes memory constructorParams,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory);

    function deployERC4626NotRedeemableMarket(
        bytes memory constructorParams,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory);

    function deployERC20Market(
        bytes memory constructorParams,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory);

    function deployCommonMarketById(
        bytes32 id,
        bytes memory constructorParams,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory);
}
