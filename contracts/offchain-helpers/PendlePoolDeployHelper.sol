// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IPAllActionV3.sol";
import "../interfaces/IPMarketFactoryV3.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketV3.sol";
// import "../core/StandardizedYield/implementations/PendleERC4626SY.sol";
import "../core/libraries/TokenHelper.sol";

contract PendlePoolDeployHelper is TokenHelper {
    address public immutable router;
    address public immutable yieldContractFactory;
    address public immutable marketFactory;

    struct PoolDeploymentParams {
        uint32 expiry;
        uint80 lnFeeRateRoot;
        int256 scalarRoot;
        int256 initialRateAnchor;
        bool doCacheIndexSameBlock;
    }

    event MarketDeployment(address indexed market, address SY, address PT, address YT, PoolDeploymentParams params);

    constructor(address _router, address _yieldContractFactory, address _marketFactory) {
        router = _router;
        yieldContractFactory = _yieldContractFactory;
        marketFactory = _marketFactory;
    }

    function deploy5115MarketAndSeedLiquidity(
        address SY,
        PoolDeploymentParams memory params,
        address tokenToSeedLiqudity,
        uint256 amountToSeed
    ) external payable returns (address PT, address YT, address market) {
        (PT, YT, market) = _deployPYAndMarket(SY, params);
        _seedLiquidity(market, SY, PT, YT, tokenToSeedLiqudity, amountToSeed);
    }

    function _deployPYAndMarket(
        address SY,
        PoolDeploymentParams memory params
    ) internal returns (address PT, address YT, address market) {
        (PT, YT) = IPYieldContractFactory(yieldContractFactory).createYieldContract(
            SY,
            params.expiry,
            params.doCacheIndexSameBlock
        );
        market = IPMarketFactoryV3(marketFactory).createNewMarket(
            PT,
            params.scalarRoot,
            params.initialRateAnchor,
            params.lnFeeRateRoot
        );
        emit MarketDeployment(market, SY, PT, YT, params);
    }

    function _seedLiquidity(address market, address SY, address PT, address YT, address token, uint256 amount) internal {
        _transferIn(token, msg.sender, amount);

        // Approval
        _safeApproveInf(token, router);
        if (token != SY) {
            _safeApproveInf(SY, router);
        }
        _safeApproveInf(PT, router);

        // Mint SY
        if (token != SY) {
            uint256 netNative = (token == NATIVE ? amount : 0);
            IPAllActionV3(router).mintSyFromToken{ value: netNative }(
                address(this),
                SY,
                0,
                TokenInput({
                    tokenIn: token,
                    netTokenIn: amount,
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
        }

        // mint PY
        IPAllActionV3(router).mintPyFromSy(address(this), YT, _selfBalance(SY) / 2, 0);

        // mint LP
        IPAllActionV3(router).addLiquidityDualSyAndPt(
            msg.sender,
            market,
            _selfBalance(SY),
            _selfBalance(PT),
            0
        );
        _transferOut(YT, msg.sender, _selfBalance(YT));
    }

    receive() external payable {}
}
