// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IExecutorHelperStruct.sol";

interface IExecutorHelper is IExecutorHelperStruct {
    // supported dexes
    function executeUniswap(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeStableSwap(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeCurve(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeKSClassic(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeUniV3KSElastic(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeBalV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeDODO(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeVelodrome(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeGMX(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executePlatypus(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeWrappedstETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeStEth(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeSynthetix(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeHashflow(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executePSM(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeFrax(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeCamelot(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeMaverick(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeSyncSwap(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeAlgebraV1(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeBalancerBatch(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeWombat(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeMantis(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeIziSwap(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeWooFiV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeTraderJoeV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executePancakeStableSwap(
        bytes memory data,
        uint256 flagsAndPrevAmountOut
    ) external payable returns (uint256);

    function executeLevelFiV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeGMXGLP(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeVooi(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeVelocoreV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeMaticMigrate(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeSmardex(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeSolidlyV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeKokonut(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeBalancerV1(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeSwaapV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeNomiswapStable(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeArbswapStable(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeBancorV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeBancorV3(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeAmbient(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeUniV1(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeLighterV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeEtherFieETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeEtherFiWeETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeKelp(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeRocketPool(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeEthenaSusde(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeMakersDAI(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeRenzo(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeWBETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeMantleETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeFrxETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeSfrxETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeSfrxETHConvertor(
        bytes memory data,
        uint256 flagsAndPrevAmountOut
    ) external payable returns (uint256);

    function executeSwellETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeRswETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeStaderETHx(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeOriginETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executePrimeETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeMantleUsd(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeBedrockUniETH(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeMaiPSM(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executePufferFinance(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeRfq(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeNative(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeKyberLimitOrder(
        bytes memory data,
        uint256 flagsAndPrevAmountOut
    ) external payable returns (uint256);

    function executeKyberDSLO(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeBebop(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeSymbioticLRT(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeMaverickV2(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeIntegral(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);

    function executeUsd0PP(bytes memory data, uint256 flagsAndPrevAmountOut) external payable returns (uint256);
}
