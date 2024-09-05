// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAggregationExecutorOptimistic as IExecutorHelperL2} from "../interfaces/IAggregationExecutorOptimistic.sol";
import {IExecutorHelper as IExecutorHelperL1} from "../interfaces/IExecutorHelper.sol";
import {IMetaAggregationRouterV2} from "../interfaces/IMetaAggregationRouterV2.sol";
import {ScalingDataL2Lib} from "./ScalingDataL2Lib.sol";
import {ExecutorReader} from "./ExecutorReader.sol";
import {CalldataWriter} from "./CalldataWriter.sol";

library InputScalingHelperL2 {
    using ExecutorReader for bytes;

    uint256 private constant _PARTIAL_FILL = 0x01;
    uint256 private constant _REQUIRES_EXTRA_ETH = 0x02;
    uint256 private constant _SHOULD_CLAIM = 0x04;
    uint256 private constant _BURN_FROM_MSG_SENDER = 0x08;
    uint256 private constant _BURN_FROM_TX_ORIGIN = 0x10;
    uint256 private constant _SIMPLE_SWAP = 0x20;

    struct PositiveSlippageFeeData {
        uint256 partnerPSInfor;
        uint256 expectedReturnAmount;
    }

    enum DexIndex {
        UNI,
        KyberDMM,
        Velodrome,
        Fraxswap,
        Camelot,
        KyberLimitOrder, // 5
        KyberRFQ, // 6
        Hashflow, // 7
        StableSwap,
        Curve,
        UniswapV3KSElastic,
        BalancerV2,
        DODO,
        GMX,
        Synthetix,
        wstETH,
        stETH,
        Platypus,
        PSM,
        Maverick,
        SyncSwap,
        AlgebraV1,
        BalancerBatch,
        Mantis,
        Wombat,
        WooFiV2,
        iZiSwap,
        TraderJoeV2, // 27
        KyberDSLO, // 28
        LevelFiV2,
        GMXGLP,
        PancakeStableSwap,
        Vooi,
        VelocoreV2,
        Smardex,
        SolidlyV2,
        Kokonut,
        BalancerV1, // 37
        SwaapV2,
        NomiswapStable,
        ArbswapStable,
        BancorV3,
        BancorV2,
        Ambient,
        Native, // 44
        LighterV2,
        Bebop, // 46
        MantleUsd,
        MaiPSM, // 48
        Kelp,
        SymbioticLRT,
        MaverickV2,
        Integral
    }

    function _getScaledInputData(bytes calldata inputData, uint256 newAmount) internal pure returns (bytes memory) {
        bytes4 selector = bytes4(inputData[:4]);
        bytes calldata dataToDecode = inputData[4:];

        if (selector == IMetaAggregationRouterV2.swap.selector) {
            IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
                dataToDecode,
                (IMetaAggregationRouterV2.SwapExecutionParams)
            );

            (params.desc, params.targetData) = _getScaledInputDataV2(
                params.desc,
                params.targetData,
                newAmount,
                _flagsChecked(params.desc.flags, _SIMPLE_SWAP)
            );
            return abi.encodeWithSelector(selector, params);
        } else if (selector == IMetaAggregationRouterV2.swapSimpleMode.selector) {
            (
                address callTarget,
                IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,
                bytes memory targetData,
                bytes memory clientData
            ) = abi.decode(dataToDecode, (address, IMetaAggregationRouterV2.SwapDescriptionV2, bytes, bytes));

            (desc, targetData) = _getScaledInputDataV2(desc, targetData, newAmount, true);
            return abi.encodeWithSelector(selector, callTarget, desc, targetData, clientData);
        } else {
            revert("InputScalingHelper: Invalid selector");
        }
    }

    function _getScaledInputDataV2(
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,
        bytes memory executorData,
        uint256 newAmount,
        bool isSimpleMode
    ) internal pure returns (IMetaAggregationRouterV2.SwapDescriptionV2 memory, bytes memory) {
        uint256 oldAmount = desc.amount;
        if (oldAmount == newAmount) {
            return (desc, executorData);
        }

        // simple mode swap
        if (isSimpleMode) {
            return (
                _scaledSwapDescriptionV2(desc, oldAmount, newAmount),
                _scaledSimpleSwapData(executorData, oldAmount, newAmount)
            );
        }

        //normal mode swap
        return (
            _scaledSwapDescriptionV2(desc, oldAmount, newAmount),
            _scaledExecutorCallBytesData(executorData, oldAmount, newAmount)
        );
    }

    /// @dev Scale the swap description
    function _scaledSwapDescriptionV2(
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (IMetaAggregationRouterV2.SwapDescriptionV2 memory) {
        desc.minReturnAmount = (desc.minReturnAmount * newAmount) / oldAmount;
        if (desc.minReturnAmount == 0) desc.minReturnAmount = 1;
        desc.amount = (desc.amount * newAmount) / oldAmount;

        uint256 nReceivers = desc.srcReceivers.length;
        for (uint256 i = 0; i < nReceivers; ) {
            desc.srcAmounts[i] = (desc.srcAmounts[i] * newAmount) / oldAmount;
            unchecked {
                ++i;
            }
        }
        return desc;
    }

    /// @dev Scale the executorData in case swapSimpleMode
    function _scaledSimpleSwapData(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IMetaAggregationRouterV2.SimpleSwapData memory simpleSwapData = abi.decode(
            data,
            (IMetaAggregationRouterV2.SimpleSwapData)
        );
        uint256 nPools = simpleSwapData.firstPools.length;
        address tokenIn;

        for (uint256 i = 0; i < nPools; ) {
            simpleSwapData.firstSwapAmounts[i] = (simpleSwapData.firstSwapAmounts[i] * newAmount) / oldAmount;

            IExecutorHelperL2.Swap[] memory dexData;

            (dexData, tokenIn) = simpleSwapData.swapDatas[i].readSwapSingleSequence();

            // only need to scale the first dex in each sequence
            if (dexData.length > 0) {
                dexData[0] = _scaleDexData(dexData[0], oldAmount, newAmount);
            }

            simpleSwapData.swapDatas[i] = CalldataWriter._writeSwapSingleSequence(abi.encode(dexData), tokenIn);

            unchecked {
                ++i;
            }
        }

        simpleSwapData.positiveSlippageData = _scaledPositiveSlippageFeeData(
            simpleSwapData.positiveSlippageData,
            oldAmount,
            newAmount
        );

        return abi.encode(simpleSwapData);
    }

    /// @dev Scale the executorData in case normal swap
    function _scaledExecutorCallBytesData(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        IExecutorHelperL2.SwapExecutorDescription memory executorDesc = abi.decode(
            data.readSwapExecutorDescription(),
            (IExecutorHelperL2.SwapExecutorDescription)
        );

        executorDesc.positiveSlippageData = _scaledPositiveSlippageFeeData(
            executorDesc.positiveSlippageData,
            oldAmount,
            newAmount
        );

        uint256 nSequences = executorDesc.swapSequences.length;
        for (uint256 i = 0; i < nSequences; ) {
            // only need to scale the first dex in each sequence
            IExecutorHelperL2.Swap memory swap = executorDesc.swapSequences[i][0];
            executorDesc.swapSequences[i][0] = _scaleDexData(swap, oldAmount, newAmount);
            unchecked {
                ++i;
            }
        }
        return CalldataWriter.writeSwapExecutorDescription(executorDesc);
    }

    function _scaledPositiveSlippageFeeData(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory newData) {
        if (data.length > 32) {
            PositiveSlippageFeeData memory psData = abi.decode(data, (PositiveSlippageFeeData));
            uint256 left = uint256(psData.expectedReturnAmount >> 128);
            uint256 right = (uint256(uint128(psData.expectedReturnAmount)) * newAmount) / oldAmount;
            require(right <= type(uint128).max, "_scaledPositiveSlippageFeeData/Exceeded type range");
            psData.expectedReturnAmount = right | (left << 128);
            data = abi.encode(psData);
        } else if (data.length == 32) {
            uint256 expectedReturnAmount = abi.decode(data, (uint256));
            uint256 left = uint256(expectedReturnAmount >> 128);
            uint256 right = (uint256(uint128(expectedReturnAmount)) * newAmount) / oldAmount;
            require(right <= type(uint128).max, "_scaledPositiveSlippageFeeData/Exceeded type range");
            expectedReturnAmount = right | (left << 128);
            data = abi.encode(expectedReturnAmount);
        }
        return data;
    }

    function _scaleDexData(
        IExecutorHelperL2.Swap memory swap,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (IExecutorHelperL2.Swap memory) {
        uint8 functionSelectorIndex = uint8(uint32(swap.functionSelector));

        if (DexIndex(functionSelectorIndex) == DexIndex.UNI) {
            swap.data = ScalingDataL2Lib.newUniSwap(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.StableSwap) {
            swap.data = ScalingDataL2Lib.newStableSwap(swap.data, oldAmount, newAmount);
        } else if (
            DexIndex(functionSelectorIndex) == DexIndex.Curve ||
            DexIndex(functionSelectorIndex) == DexIndex.PancakeStableSwap
        ) {
            swap.data = ScalingDataL2Lib.newCurveSwap(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.KyberDMM) {
            swap.data = ScalingDataL2Lib.newKyberDMM(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.UniswapV3KSElastic) {
            swap.data = ScalingDataL2Lib.newUniswapV3KSElastic(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.BalancerV2) {
            swap.data = ScalingDataL2Lib.newBalancerV2(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.wstETH) {
            swap.data = ScalingDataL2Lib.newWrappedstETHSwap(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.stETH) {
            swap.data = ScalingDataL2Lib.newStETHSwap(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.DODO) {
            swap.data = ScalingDataL2Lib.newDODO(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Velodrome) {
            swap.data = ScalingDataL2Lib.newVelodrome(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.GMX) {
            swap.data = ScalingDataL2Lib.newGMX(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Synthetix) {
            swap.data = ScalingDataL2Lib.newSynthetix(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Camelot) {
            swap.data = ScalingDataL2Lib.newCamelot(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.PSM) {
            swap.data = ScalingDataL2Lib.newPSM(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Fraxswap) {
            swap.data = ScalingDataL2Lib.newFrax(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Platypus) {
            swap.data = ScalingDataL2Lib.newPlatypus(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Maverick) {
            swap.data = ScalingDataL2Lib.newMaverick(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.SyncSwap) {
            swap.data = ScalingDataL2Lib.newSyncSwap(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.AlgebraV1) {
            swap.data = ScalingDataL2Lib.newAlgebraV1(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.BalancerBatch) {
            swap.data = ScalingDataL2Lib.newBalancerBatch(swap.data, oldAmount, newAmount);
        } else if (
            DexIndex(functionSelectorIndex) == DexIndex.Mantis ||
            DexIndex(functionSelectorIndex) == DexIndex.Wombat ||
            DexIndex(functionSelectorIndex) == DexIndex.WooFiV2 ||
            DexIndex(functionSelectorIndex) == DexIndex.Smardex ||
            DexIndex(functionSelectorIndex) == DexIndex.SolidlyV2 ||
            DexIndex(functionSelectorIndex) == DexIndex.NomiswapStable ||
            DexIndex(functionSelectorIndex) == DexIndex.BancorV3
        ) {
            swap.data = ScalingDataL2Lib.newMantis(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.iZiSwap) {
            swap.data = ScalingDataL2Lib.newIziSwap(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.TraderJoeV2) {
            swap.data = ScalingDataL2Lib.newTraderJoeV2(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.LevelFiV2) {
            swap.data = ScalingDataL2Lib.newLevelFiV2(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.GMXGLP) {
            swap.data = ScalingDataL2Lib.newGMXGLP(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Vooi) {
            swap.data = ScalingDataL2Lib.newVooi(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.VelocoreV2) {
            swap.data = ScalingDataL2Lib.newVelocoreV2(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Kokonut) {
            swap.data = ScalingDataL2Lib.newKokonut(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.BalancerV1) {
            swap.data = ScalingDataL2Lib.newBalancerV1(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.ArbswapStable) {
            swap.data = ScalingDataL2Lib.newArbswapStable(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.BancorV2) {
            swap.data = ScalingDataL2Lib.newBancorV2(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Ambient) {
            swap.data = ScalingDataL2Lib.newAmbient(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.LighterV2) {
            swap.data = ScalingDataL2Lib.newLighterV2(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Bebop) {
            swap.data = ScalingDataL2Lib.newBebop(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.KyberLimitOrder) {
            swap.data = ScalingDataL2Lib.newKyberLimitOrder(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.MaiPSM) {
            swap.data = ScalingDataL2Lib.newMaiPSM(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Native) {
            swap.data = ScalingDataL2Lib.newNative(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.KyberDSLO) {
            swap.data = ScalingDataL2Lib.newKyberDSLO(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Hashflow) {
            swap.data = ScalingDataL2Lib.newHashflow(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.KyberRFQ) {
            swap.data = ScalingDataL2Lib.newKyberRFQ(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.MantleUsd) {
            swap.data = ScalingDataL2Lib.newMantleUsd(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Kelp) {
            swap.data = ScalingDataL2Lib.newKelp(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.SymbioticLRT) {
            swap.data = ScalingDataL2Lib.newSymbioticLRT(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.MaverickV2) {
            swap.data = ScalingDataL2Lib.newMaverickV2(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.Integral) {
            swap.data = ScalingDataL2Lib.newIntegral(swap.data, oldAmount, newAmount);
        } else if (DexIndex(functionSelectorIndex) == DexIndex.SwaapV2) {
            revert("InputScalingHelper: Can not scale SwaapV2 swap");
        } else {
            revert("InputScaleHelper: Dex type not supported");
        }
        return swap;
    }

    function _flagsChecked(uint256 number, uint256 flag) internal pure returns (bool) {
        return number & flag != 0;
    }
}
