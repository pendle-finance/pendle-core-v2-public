// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendlePoolDeployHelperV2.sol";
import "../../interfaces/IPCommonSYFactory.sol";
import "../../interfaces/IOwnable.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";

contract PendleCommonPoolDeployHelperV2 is PendlePoolDeployHelperV2, BoringOwnableUpgradeable {
    bytes32 public constant ERC4626_DEPLOY_ID = keccak256("PendleERC4626SYV2");
    bytes32 public constant ERC4626_NOT_REDEEMABLE_DEPLOY_ID = keccak256("PendleERC4626NotRedeemableToAssetSYV2");
    bytes32 public constant ERC20_DEPLOY_ID = keccak256("PendleERC20SY");

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

    function initialize() external initializer {
        __BoringOwnable_init();
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
}
