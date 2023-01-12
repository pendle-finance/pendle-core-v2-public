// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";

import "../../interfaces/IWETH.sol";

import "./interfaces/IMetaAggregationRouter.sol";
import "./interfaces/IMetaAggregationRouterV2.sol";
import "./interfaces/IHashflow.sol";
import "./interfaces/IExecutorHelperEthereum1.sol";

import "./IAggregatorRouterHelper.sol";
import "./ScaleDataHelperEthereum1.sol";

contract AggregationRouterHelper is
    IAggregationRouterHelper,
    Initializable,
    UUPSUpgradeable,
    BoringOwnableUpgradeable
{
    uint256 private constant _PARTIAL_FILL = 0x01;
    uint256 private constant _REQUIRES_EXTRA_ETH = 0x02;
    uint256 private constant _SHOULD_CLAIM = 0x04;
    uint256 private constant _BURN_FROM_MSG_SENDER = 0x08;
    uint256 private constant _BURN_FROM_TX_ORIGIN = 0x10;
    uint256 private constant _SIMPLE_SWAP = 0x20;

    constructor() initializer {}

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    struct Swap {
        bytes data;
        bytes4 selector;
    }

    struct SimpleSwapData {
        address[] firstPools;
        uint256[] firstSwapAmounts;
        bytes[] swapDatas;
        uint256 deadline;
        bytes destTokenFeeData;
    }

    struct SwapExecutorDescription {
        Swap[][] swapSequences;
        address tokenIn;
        address tokenOut;
        uint256 minTotalAmountOut;
        address to;
        uint256 deadline;
        bytes destTokenFeeData;
    }

    function getScaledInputData(bytes calldata kybercall, uint256 newAmount)
        external
        pure
        returns (bytes memory)
    {
        bytes4 selector = bytes4(kybercall[:4]);

        if (selector == IWETH.deposit.selector) {
            return kybercall; // no scaling needed
        }

        if (selector == IWETH.withdraw.selector) {
            return abi.encodeWithSelector(selector, newAmount);
        }

        if (
            selector == IMetaAggregationRouter.swap.selector ||
            selector == IMetaAggregationRouter.swapSimpleMode.selector
        ) {
            (
                address callTarget,
                IMetaAggregationRouter.SwapDescription memory desc,
                bytes memory targetData,
                bytes memory clientData
            ) = abi.decode(
                    kybercall[4:],
                    (address, IMetaAggregationRouter.SwapDescription, bytes, bytes)
                );

            (desc, targetData) = _getScaledInputDataV1(
                desc,
                targetData,
                newAmount,
                selector == IMetaAggregationRouter.swapSimpleMode.selector ||
                    _flagsChecked(desc.flags, _SIMPLE_SWAP)
            );
            return abi.encodeWithSelector(selector, callTarget, desc, targetData, clientData);
        }

        if (selector == IMetaAggregationRouterV2.swap.selector) {
            IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
                kybercall[4:],
                (IMetaAggregationRouterV2.SwapExecutionParams)
            );

            (params.desc, params.targetData) = _getScaledInputDataV2(
                params.desc,
                params.targetData,
                newAmount,
                _flagsChecked(params.desc.flags, _SIMPLE_SWAP)
            );
            return abi.encodeWithSelector(selector, params);
        }

        if (selector == IMetaAggregationRouterV2.swapSimpleMode.selector) {
            (
                address callTarget,
                IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,
                bytes memory targetData,
                bytes memory clientData
            ) = abi.decode(
                    kybercall[4:],
                    (address, IMetaAggregationRouterV2.SwapDescriptionV2, bytes, bytes)
                );

            (desc, targetData) = _getScaledInputDataV2(desc, targetData, newAmount, true);
            return abi.encodeWithSelector(selector, callTarget, desc, targetData, clientData);
        }

        revert("InputScalingHelper: Invalid selector");
    }

    function _getScaledInputDataV1(
        IMetaAggregationRouter.SwapDescription memory desc,
        bytes memory executorData,
        uint256 newAmount,
        bool isSimpleMode
    ) internal pure returns (IMetaAggregationRouter.SwapDescription memory, bytes memory) {
        uint256 oldAmount = desc.amount;
        if (oldAmount == newAmount) {
            return (desc, executorData);
        }

        // simple mode swap
        if (isSimpleMode) {
            return (
                _scaledSwapDescriptionV1(desc, oldAmount, newAmount),
                _scaledSimpleSwapData(executorData, oldAmount, newAmount)
            );
        }

        //normal mode swap
        return (
            _scaledSwapDescriptionV1(desc, oldAmount, newAmount),
            _scaledExecutorCallBytesData(executorData, oldAmount, newAmount)
        );
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

    function _scaledSwapDescriptionV1(
        IMetaAggregationRouter.SwapDescription memory desc,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (IMetaAggregationRouter.SwapDescription memory) {
        uint256 oldMinReturnAmount = desc.minReturnAmount;
        desc.minReturnAmount = (desc.minReturnAmount * newAmount) / oldAmount;
        //newMinReturnAmount should no be 0 if oldMinReturnAmount > 0
        if (oldMinReturnAmount > 0 && desc.minReturnAmount == 0) desc.minReturnAmount = 1;
        desc.amount = newAmount;
        if (desc.srcReceivers.length == 0) {
            return desc;
        }

        uint256 newTotal;
        for (uint256 i = 0; i < desc.srcReceivers.length; i++) {
            if (i == desc.srcReceivers.length - 1) {
                desc.srcAmounts[i] = newAmount - newTotal;
            } else {
                desc.srcAmounts[i] = (desc.srcAmounts[i] * newAmount) / oldAmount;
            }
            newTotal += desc.srcAmounts[i];
        }
        return desc;
    }

    function _scaledSimpleSwapData(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        SimpleSwapData memory swapData = abi.decode(data, (SimpleSwapData));
        uint256 numberSeq = swapData.firstPools.length;
        uint256 newTotalSwapAmount;
        for (uint256 i = 0; i < numberSeq; i++) {
            if (i == numberSeq - 1) {
                swapData.firstSwapAmounts[i] = newAmount - newTotalSwapAmount;
            } else {
                swapData.firstSwapAmounts[i] =
                    (swapData.firstSwapAmounts[i] * newAmount) /
                    oldAmount;
            }
            newTotalSwapAmount += swapData.firstSwapAmounts[i];
        }
        return abi.encode(swapData);
    }

    function _scaledExecutorCallBytesData(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        SwapExecutorDescription memory executorDesc = abi.decode(data, (SwapExecutorDescription));
        executorDesc.minTotalAmountOut = (executorDesc.minTotalAmountOut * newAmount) / oldAmount;
        for (uint256 i = 0; i < executorDesc.swapSequences.length; i++) {
            Swap memory swap = executorDesc.swapSequences[i][0];
            bytes4 selector = swap.selector;

            if (selector == IExecutorHelperEthereum1.executeUniSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newUniSwap(swap.data, oldAmount, newAmount);
            } else if (selector == IExecutorHelperEthereum1.executeStableSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newStableSwap(
                    swap.data,
                    oldAmount,
                    newAmount
                );
            } else if (selector == IExecutorHelperEthereum1.executeCurveSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newCurveSwap(swap.data, oldAmount, newAmount);
            } else if (selector == IExecutorHelperEthereum1.executeKyberDMMSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newKyberDMM(swap.data, oldAmount, newAmount);
            } else if (selector == IExecutorHelperEthereum1.executeUniV3ProMMSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newUniV3ProMM(
                    swap.data,
                    oldAmount,
                    newAmount
                );
            } else if (selector == IExecutorHelperEthereum1.executeRfqSwap.selector) {
                revert("InputScalingHelper: Can not scale RFQ swap");
            } else if (selector == IExecutorHelperEthereum1.executeBalV2Swap.selector) {
                swap.data = ScaleDataHelperEthereum1.newBalancerV2(
                    swap.data,
                    oldAmount,
                    newAmount
                );
            } else if (selector == IExecutorHelperEthereum1.executeDODOSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newDODO(swap.data, oldAmount, newAmount);
            } else if (selector == IExecutorHelperEthereum1.executeWrappedstETHSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newWrappedstETHSwap(
                    swap.data,
                    oldAmount,
                    newAmount
                );
            } else if (selector == IExecutorHelperEthereum1.executeSynthetixSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newSynthetix(swap.data, oldAmount, newAmount);
            } else if (selector == IExecutorHelperEthereum1.executePSMSwap.selector) {
                swap.data = ScaleDataHelperEthereum1.newPSM(swap.data, oldAmount, newAmount);
            } else if (selector == IExecutorHelperEthereum1.executeHashflowSwap.selector) {
                revert("InputScalingHelper: Can not scale RFQ swap");
            } else revert("AggregationExecutor: Dex type not supported");
        }
        return abi.encode(executorDesc);
    }

    function _scaledSwapDescriptionV2(
        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (IMetaAggregationRouterV2.SwapDescriptionV2 memory) {
        uint256 oldMinReturnAmount = desc.minReturnAmount;
        desc.minReturnAmount = (desc.minReturnAmount * newAmount) / oldAmount;
        //newMinReturnAmount should no be 0 if oldMinReturnAmount > 0
        if (oldMinReturnAmount > 0 && desc.minReturnAmount == 0) desc.minReturnAmount = 1;
        desc.amount = newAmount;
        if (desc.srcReceivers.length == 0) {
            return desc;
        }

        uint256 newTotal;
        for (uint256 i = 0; i < desc.srcReceivers.length; i++) {
            if (i == desc.srcReceivers.length - 1) {
                desc.srcAmounts[i] = newAmount - newTotal;
            } else {
                desc.srcAmounts[i] = (desc.srcAmounts[i] * newAmount) / oldAmount;
            }
            newTotal += desc.srcAmounts[i];
        }
        return desc;
    }

    function _flagsChecked(uint256 number, uint256 flag) internal pure returns (bool) {
        return number & flag != 0;
    }
}
