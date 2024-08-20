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

    function seedLiquidity(address market, address tokenToSeedLiqudity, uint256 amountToSeed) external payable {
        (IStandardizedYield SY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();
        _seedLiquidity(market, address(SY), address(PT), address(YT), tokenToSeedLiqudity, amountToSeed);
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

    function _seedLiquidity(
        address market,
        address SY,
        address PT,
        address YT,
        address token,
        uint256 amountToSeed
    ) internal {
        _transferIn(token, msg.sender, amountToSeed);

        // Approval
        _safeApproveInf(token, router);
        if (token != SY) {
            _safeApproveInf(SY, router);
        }
        _safeApproveInf(PT, router);

        // Mint SY
        uint256 amountSY;
        if (token != SY) {
            uint256 netNative = (token == NATIVE ? amountToSeed : 0);
            amountSY = IPAllActionV3(router).mintSyFromToken{value: netNative}(
                address(this),
                SY,
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

        // mint PY
        uint256 amountPY = IPAllActionV3(router).mintPyFromSy(address(this), YT, amountSY / 2, 0);

        // mint LP
        IPAllActionV3(router).addLiquidityDualSyAndPt(msg.sender, market, amountSY / 2, amountPY, 0);
        _transferOut(YT, msg.sender, amountPY);
    }

    function redeployMarket(
        address oldMarket,
        uint256 amountLp,
        uint80 lnFeeRateRoot,
        int256 scalarRoot,
        int256 initialRateAnchor
    ) external returns (address newMarket) {
        (, IPPrincipalToken PT, ) = IPMarket(oldMarket).readTokens();
        newMarket = IPMarketFactoryV3(marketFactory).createNewMarket(
            address(PT),
            scalarRoot,
            initialRateAnchor,
            lnFeeRateRoot
        );
        _transferFrom(IERC20(oldMarket), msg.sender, oldMarket, amountLp);
        (uint256 netSyOut, uint256 netPtOut) = IPMarketV3(oldMarket).burn(newMarket, newMarket, amountLp);
        IPMarketV3(newMarket).mint(msg.sender, netSyOut, netPtOut);
    }

    receive() external payable {}
}
