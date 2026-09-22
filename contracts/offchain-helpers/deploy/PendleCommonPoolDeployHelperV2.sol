// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../core/libraries/BoringOwnableUpgradeableV2.sol";
import "../../interfaces/IOwnable.sol";
import "../../interfaces/IPCommonSYFactory.sol";
import "./PendlePoolDeployHelperV2.sol";

contract PendleCommonPoolDeployHelperV2 is PendlePoolDeployHelperV2, BoringOwnableUpgradeableV2 {
    address public immutable syFactory;

    constructor(address _syFactory, address _router, address _yieldContractFactory, address _marketFactory)
        PendlePoolDeployHelperV2(_router, _yieldContractFactory, _marketFactory)
    {
        syFactory = _syFactory;
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function deployCommonMarketById(
        bytes32 id,
        bytes memory constructorParams,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory) {
        address SY = IPCommonSYFactory(syFactory).deploySY(id, constructorParams, syOwner);
        return deploy5115MarketAndSeedLiquidity(SY, config, tokenToSeedLiqudity, amountToSeed);
    }

    function deployCommonMarketById(
        bytes32 id,
        bytes memory constructorParams,
        bytes memory initData,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory) {
        address SY = IPCommonSYFactory(syFactory).deployUpgradableSY(id, constructorParams, initData, syOwner);
        return deploy5115MarketAndSeedLiquidity(SY, config, tokenToSeedLiqudity, amountToSeed);
    }
}
