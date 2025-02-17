// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../core/libraries/TokenHelper.sol";
import "../../interfaces/IPAllActionV3.sol";
import "../../interfaces/IPMarketFactoryV3.sol";
import "../../interfaces/IPYieldContractFactory.sol";
import "../../interfaces/IPMarketV3.sol";
import "./lib/MarketDeployLib.sol";

contract PendlePoolDeployHelperV2 is TokenHelper {
    using PMath for uint256;
    using PMath for int256;

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

    // solhint-disable immutable-vars-naming
    address public immutable router;
    address public immutable yieldContractFactory;
    address public immutable marketFactory;
    bool public immutable doCacheIndexSameBlock;

    constructor(address _router, address _yieldContractFactory, address _marketFactory) {
        doCacheIndexSameBlock = block.chainid == 1;
        router = _router;
        yieldContractFactory = _yieldContractFactory;
        marketFactory = _marketFactory;
    }

    function deploy5115MarketAndSeedLiquidity(
        address SY,
        PoolConfig memory config,
        address tokenToSeedLiqudity,
        uint256 amountToSeed
    ) public payable returns (PoolDeploymentAddrs memory) {
        (PoolDeploymentParams memory params, PoolDeploymentAddrs memory addrs) = _deployPYAndMarket(SY, config);
        _seedLiquidity(params, addrs, tokenToSeedLiqudity, amountToSeed, config.desiredImpliedRate);
        return addrs;
    }

    function _deployPYAndMarket(
        address SY,
        PoolConfig memory config
    ) internal returns (PoolDeploymentParams memory params, PoolDeploymentAddrs memory addrs) {
        (uint256 scalarRoot, uint256 initialRateAnchor) = MarketDeployLib.calcParams(
            config.rateMin,
            config.rateMax,
            config.expiry
        );

        params = PoolDeploymentParams({
            expiry: config.expiry,
            lnFeeRateRoot: MarketDeployLib.calcFee(config.fee),
            scalarRoot: scalarRoot.Int(),
            initialRateAnchor: initialRateAnchor.Int(),
            doCacheIndexSameBlock: doCacheIndexSameBlock
        });

        addrs.SY = SY;
        (addrs.PT, addrs.YT) = IPYieldContractFactory(yieldContractFactory).createYieldContract(
            SY,
            params.expiry,
            params.doCacheIndexSameBlock
        );

        addrs.market = IPMarketFactoryV3(marketFactory).createNewMarket(
            addrs.PT,
            params.scalarRoot,
            params.initialRateAnchor,
            params.lnFeeRateRoot
        );

        emit MarketDeployment(addrs, params);
    }

    function _seedLiquidity(
        PoolDeploymentParams memory params,
        PoolDeploymentAddrs memory addrs,
        address token,
        uint256 amountToSeed,
        uint256 desiredImpliedRate
    ) internal {
        _transferIn(token, msg.sender, amountToSeed);

        // Approval
        _safeApproveInf(token, router);
        if (token != addrs.SY) {
            _safeApproveInf(addrs.SY, router);
        }
        _safeApproveInf(addrs.PT, router);

        // Mint SY
        uint256 amountSY;
        if (token != addrs.SY) {
            uint256 netNative = (token == NATIVE ? amountToSeed : 0);
            amountSY = IPAllActionV3(router).mintSyFromToken{value: netNative}(
                address(this),
                addrs.SY,
                0,
                TokenInput({
                    tokenIn: token,
                    netTokenIn: amountToSeed,
                    tokenMintSy: token,
                    pendleSwap: address(0),
                    swapData: SwapData({
                        swapType: SwapType.NONE,
                        extRouter: address(0),
                        extCalldata: abi.encode(),
                        needScale: false
                    })
                })
            );
        } else {
            amountSY = amountToSeed;
        }

        uint256 initialProportion = MarketDeployLib.calcInitialProportion(
            params.expiry,
            params.scalarRoot.Uint(),
            params.initialRateAnchor.Uint(),
            desiredImpliedRate
        );

        // mint PY
        uint256 amountPY = IPAllActionV3(router).mintPyFromSy(
            address(this),
            addrs.YT,
            amountSY.mulDown(initialProportion),
            0
        );

        // mint LP
        IPAllActionV3(router).addLiquidityDualSyAndPt(msg.sender, addrs.market, _selfBalance(addrs.SY), amountPY, 0);
        _transferOut(addrs.YT, msg.sender, amountPY);
    }
}
