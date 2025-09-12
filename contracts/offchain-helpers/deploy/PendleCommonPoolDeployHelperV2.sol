// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendlePoolDeployHelperV2.sol";
import "../../interfaces/IPCommonSYFactory.sol";
import "../../interfaces/IOwnable.sol";
import "../../core/libraries/BoringOwnableUpgradeableV2.sol";

contract PendleCommonPoolDeployHelperV2 is PendlePoolDeployHelperV2, BoringOwnableUpgradeableV2 {
    
    bytes32 public constant ERC4626_DEPLOY_ID = keccak256("PendleERC4626SYV2");                                     // 0x1278efc0e6754cd30fef2df25ff5ced072ebb194d348b0b1b9548166d24352ef
    bytes32 public constant ERC4626_NOT_REDEEMABLE_DEPLOY_ID = keccak256("PendleERC4626NotRedeemableToAssetSYV2");  // 0x6f089cd4afdd945c5c26b3f4542d0c294d19ec0e339c6ce4f8eafa94d700d05d
    bytes32 public constant ERC20_DEPLOY_ID = keccak256("PendleERC20SY");                                           // 0xfcf22a9a515753d83e4f2a81cf368c7226408c64f52411ae95241ebf5ed53304
    
    bytes32 public constant ERC4626_WITH_ADAPTER_ID = keccak256("PendleERC4626WithAdapterSY");                      // 0x73f41560741d6765943d3c955034291fe23d9141e3a4719bc97422d5bf019adc
    bytes32 public constant ERC4626_NO_REDEEM_WITH_ADAPTER_ID = keccak256("PendleERC4626NoRedeemWithAdapterSY");    // 0x3b8dd2b992f773444e5422ba1db289c4657c57110d740dca7975dc095632ef23
    bytes32 public constant ERC20_WITH_ADAPTER_ID = keccak256("PendleERC20WithAdapterSY");                          // 0xe5cce2b1999bf8c2cc4cf6d96d0569a24d8b782ba1647c09a8e1aa8bbfb98996
    bytes32 public constant ERC4626_NO_DEPOSIT_NO_REDEEM = keccak256("PendleERC4626NoRedeemNoDepositUpgSY");        // 0x5c1cddc0128e0b02bb711f84a022bf1c13177d4ab028830b702f3a77280025ea

    address public immutable syFactory;

    constructor(
        address _syFactory,
        address _router,
        address _yieldContractFactory,
        address _marketFactory
    ) PendlePoolDeployHelperV2(_router, _yieldContractFactory, _marketFactory) {
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

    // Those 3 are all not payable as they should not accept tokenIn as native

    function deployERC4626Market(
        bytes memory constructorParams,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory) {
        address SY = IPCommonSYFactory(syFactory).deploySY(ERC4626_DEPLOY_ID, constructorParams, syOwner);
        return deploy5115MarketAndSeedLiquidity(SY, config, tokenToSeedLiqudity, amountToSeed);
    }

    function deployERC4626NotRedeemableMarket(
        bytes memory constructorParams,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory) {
        address SY = IPCommonSYFactory(syFactory).deploySY(
            ERC4626_NOT_REDEEMABLE_DEPLOY_ID,
            constructorParams,
            syOwner
        );
        return deploy5115MarketAndSeedLiquidity(SY, config, tokenToSeedLiqudity, amountToSeed);
    }

    function deployERC20Market(
        bytes memory constructorParams,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory) {
        address SY = IPCommonSYFactory(syFactory).deploySY(ERC20_DEPLOY_ID, constructorParams, syOwner);
        return deploy5115MarketAndSeedLiquidity(SY, config, tokenToSeedLiqudity, amountToSeed);
    }

    function deployERC4626WithAdapterMarket(
        bytes memory constructorParams,
        bytes memory initData,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory) {
        address SY = IPCommonSYFactory(syFactory).deployUpgradableSY(
            ERC4626_WITH_ADAPTER_ID,
            constructorParams,
            initData,
            syOwner
        );
        return deploy5115MarketAndSeedLiquidity(SY, config, tokenToSeedLiqudity, amountToSeed);
    }

    function deployERC4626NoRedeemWithAdapterMarket(
        bytes memory constructorParams,
        bytes memory initData,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory) {
        address SY = IPCommonSYFactory(syFactory).deployUpgradableSY(
            ERC4626_NO_REDEEM_WITH_ADAPTER_ID,
            constructorParams,
            initData,
            syOwner
        );
        return deploy5115MarketAndSeedLiquidity(SY, config, tokenToSeedLiqudity, amountToSeed);
    }

    function deployERC20WithAdapterMarket(
        bytes memory constructorParams,
        bytes memory initData,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed,
        address syOwner
    ) external returns (PoolDeploymentAddrs memory) {
        address SY = IPCommonSYFactory(syFactory).deployUpgradableSY(
            ERC20_WITH_ADAPTER_ID,
            constructorParams,
            initData,
            syOwner
        );
        return deploy5115MarketAndSeedLiquidity(SY, config, tokenToSeedLiqudity, amountToSeed);
    }
}
