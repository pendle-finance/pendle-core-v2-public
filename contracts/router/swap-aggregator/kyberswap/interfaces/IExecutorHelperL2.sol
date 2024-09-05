pragma solidity ^0.8.0;

import {IKyberDSLO} from "./pools/IKyberDSLO.sol";
import "./IExecutorHelperL2Struct.sol";

interface IExecutorHelperL2 is IExecutorHelperL2Struct {
    function executeUniswap(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeKSClassic(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeVelodrome(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeFrax(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeCamelot(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeKyberLimitOrder(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeStableSwap(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeCurve(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeUniV3KSElastic(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeBalV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeDODO(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeGMX(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeSynthetix(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeWrappedstETH(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeStEth(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executePlatypus(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executePSM(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeMaverick(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeSyncSwap(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeAlgebraV1(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeBalancerBatch(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeWombat(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeWooFiV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeMantis(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeIziSwap(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeTraderJoeV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeLevelFiV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeGMXGLP(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executePancakeStableSwap(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeMantleUsd(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeKelp(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeVooi(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeVelocoreV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeSmardex(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeSolidlyV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeKokonut(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeBalancerV1(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeSwaapV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeNomiswapStable(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeArbswapStable(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeBancorV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeBancorV3(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeAmbient(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeLighterV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeMaiPSM(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeNative(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeHashflow(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeRfq(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeKyberDSLO(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeBebop(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeSymbioticLRT(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeMaverickV2(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);

    function executeIntegral(
        uint256 index,
        bytes memory data,
        uint256 previousAmountOut,
        address tokenIn,
        bool getPoolOnly,
        address nextPool
    ) external payable returns (address tokenOut, uint256 tokenAmountOut, address pool);
}
