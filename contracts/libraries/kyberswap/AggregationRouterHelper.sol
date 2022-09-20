// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMultihopRouter.sol";

library AggregationRouterHelper {
    uint256 private constant _PARTIAL_FILL = 0x01;
    uint256 private constant _REQUIRES_EXTRA_ETH = 0x02;
    uint256 private constant _SHOULD_CLAIM = 0x04;
    uint256 private constant _BURN_FROM_MSG_SENDER = 0x08;
    uint256 private constant _BURN_FROM_TX_ORIGIN = 0x10;
    uint256 private constant _SIMPLE_SWAP = 0x20;

    uint256 private constant SLIPPAGE_RANGE = 10; // over 100

    enum DexType {
        UNI,
        STABLESWAP,
        CURVE,
        KYBERDMM,
        SADDLE,
        UNIV3PROMM,
        BALANCERV2,
        KYBERRFQ,
        DODO,
        VELODROME,
        PLATYPUS
    }

    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address[] srcReceivers;
        uint256[] srcAmounts;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    struct SimpleSwapData {
        address[] firstPools;
        uint256[] firstSwapAmounts;
        bytes[] swapDatas;
        uint256 deadline;
        bytes destTokenFeeData;
    }

    struct SwapExecutorDescription {
        IMultihopRouter.Swap[][] swapSequences;
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
        (
            address caller,
            SwapDescription memory desc,
            bytes memory executorData,
            bytes memory clientData
        ) = abi.decode(kybercall[4:], (address, SwapDescription, bytes, bytes));

        (desc, executorData) = _getScaledInputData(desc, executorData, newAmount);
        return abi.encodeWithSelector(selector, caller, desc, executorData, clientData);
    }

    function _getScaledInputData(
        SwapDescription memory desc,
        bytes memory executorData,
        uint256 newAmount
    ) internal pure returns (SwapDescription memory, bytes memory) {
        uint256 flags = desc.flags;
        uint256 oldAmount = desc.amount;
        if (oldAmount == newAmount) {
            return (desc, executorData);
        }

        // simple mode swap
        if (flags & _SIMPLE_SWAP != 0) {
            require(desc.srcReceivers.length == 0, "kyber: can't scale if take fee");
            return (
                _getNewDescription(desc, oldAmount, newAmount),
                _getNewSimpleSwapData(executorData, oldAmount, newAmount)
            );
        }

        //normal mode swap
        bytes memory newExecutorData = _getNewExecutorData(executorData, oldAmount, newAmount);
        return (_getNewDescription(desc, oldAmount, newAmount), newExecutorData);
    }

    function _getNewDescription(
        SwapDescription memory desc,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (SwapDescription memory) {
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

    function _getNewSimpleSwapData(
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

    function _getNewExecutorData(
        bytes memory data,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory) {
        SwapExecutorDescription memory swapExecutorDescription = abi.decode(
            data,
            (SwapExecutorDescription)
        );
        swapExecutorDescription.minTotalAmountOut =
            (swapExecutorDescription.minTotalAmountOut * newAmount) /
            oldAmount;

        uint256 newTotalSwapAmount;
        for (uint256 i = 0; i < swapExecutorDescription.swapSequences.length; i++) {
            IMultihopRouter.Swap memory swap = swapExecutorDescription.swapSequences[i][0];
            uint8 dexType = uint8(swap.dexOption >> 8);
            uint256 value;
            if (i == swapExecutorDescription.swapSequences.length - 1)
                value = newAmount - newTotalSwapAmount;

            if (dexType == uint8(DexType.UNI)) {
                (swap.data, value) = _newUniSwap(swap.data, value, oldAmount, newAmount);
            } else if (dexType == uint8(DexType.STABLESWAP) || dexType == uint8(DexType.SADDLE)) {
                (swap.data, value) = _newStableSwap(swap.data, value, oldAmount, newAmount);
            } else if (dexType == uint8(DexType.CURVE)) {
                (swap.data, value) = _newCurveSwap(swap.data, value, oldAmount, newAmount);
            } else if (dexType == uint8(DexType.KYBERDMM)) {
                (swap.data, value) = _newKyberDMMSwap(swap.data, value, oldAmount, newAmount);
            } else if (dexType == uint8(DexType.UNIV3PROMM)) {
                (swap.data, value) = _newUniV3ProMMSwap(swap.data, value, oldAmount, newAmount);
            } else if (dexType == uint8(DexType.BALANCERV2)) {
                (swap.data, value) = _newBalancerV2Swap(swap.data, value, oldAmount, newAmount);
            } else if (dexType == uint8(DexType.KYBERRFQ)) {
                revert("kyber: can't scale kyberrfq");
            } else if (dexType == uint8(DexType.DODO)) {
                (swap.data, value) = _newDODOSwap(swap.data, value, oldAmount, newAmount);
            } else if (dexType == uint8(DexType.VELODROME)) {
                (swap.data, value) = _newVelodromeSwap(swap.data, value, oldAmount, newAmount);
            } else {
                revert("AggregationExecutor: Dex type not supported");
            }
            newTotalSwapAmount += value;
        }
        return abi.encode(swapExecutorDescription);
    }

    function _newUniSwap(
        bytes memory data,
        uint256 value,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory, uint256) {
        IMultihopRouter.UniSwap memory uniSwap = abi.decode(data, (IMultihopRouter.UniSwap));
        if (value > 0) uniSwap.collectAmount = value;
        else uniSwap.collectAmount = (uniSwap.collectAmount * newAmount) / oldAmount;
        return (abi.encode(uniSwap), uniSwap.collectAmount);
    }

    function _newStableSwap(
        bytes memory data,
        uint256 value,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory, uint256) {
        IMultihopRouter.StableSwap memory stableSwap = abi.decode(
            data,
            (IMultihopRouter.StableSwap)
        );
        if (value > 0) stableSwap.dx = value;
        else stableSwap.dx = (stableSwap.dx * newAmount) / oldAmount;
        return (abi.encode(stableSwap), stableSwap.dx);
    }

    function _newCurveSwap(
        bytes memory data,
        uint256 value,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory, uint256) {
        IMultihopRouter.CurveSwap memory curveSwap = abi.decode(data, (IMultihopRouter.CurveSwap));
        if (value > 0) curveSwap.dx = value;
        else curveSwap.dx = (curveSwap.dx * newAmount) / oldAmount;
        return (abi.encode(curveSwap), curveSwap.dx);
    }

    function _newKyberDMMSwap(
        bytes memory data,
        uint256 value,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory, uint256) {
        IMultihopRouter.UniSwap memory kyberDMMSwap = abi.decode(data, (IMultihopRouter.UniSwap));
        if (value > 0) kyberDMMSwap.collectAmount = value;
        else kyberDMMSwap.collectAmount = (kyberDMMSwap.collectAmount * newAmount) / oldAmount;
        return (abi.encode(kyberDMMSwap), kyberDMMSwap.collectAmount);
    }

    function _newUniV3ProMMSwap(
        bytes memory data,
        uint256 value,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory, uint256) {
        IMultihopRouter.UniSwapV3ProMM memory uniSwapV3ProMM = abi.decode(
            data,
            (IMultihopRouter.UniSwapV3ProMM)
        );
        if (value > 0) uniSwapV3ProMM.swapAmount = value;
        else uniSwapV3ProMM.swapAmount = (uniSwapV3ProMM.swapAmount * newAmount) / oldAmount;
        return (abi.encode(uniSwapV3ProMM), uniSwapV3ProMM.swapAmount);
    }

    function _newBalancerV2Swap(
        bytes memory data,
        uint256 value,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory, uint256) {
        IMultihopRouter.BalancerV2 memory balancerV2 = abi.decode(
            data,
            (IMultihopRouter.BalancerV2)
        );
        if (value > 0) balancerV2.amount = value;
        else balancerV2.amount = (balancerV2.amount * newAmount) / oldAmount;
        return (abi.encode(balancerV2, balancerV2.amount), balancerV2.amount);
    }

    function _newDODOSwap(
        bytes memory data,
        uint256 value,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory, uint256) {
        IMultihopRouter.DODO memory dodo = abi.decode(data, (IMultihopRouter.DODO));
        if (value > 0) dodo.amount = value;
        else dodo.amount = (dodo.amount * newAmount) / oldAmount;
        return (abi.encode(dodo), dodo.amount);
    }

    function _newVelodromeSwap(
        bytes memory data,
        uint256 value,
        uint256 oldAmount,
        uint256 newAmount
    ) internal pure returns (bytes memory, uint256) {
        IMultihopRouter.UniSwap memory velodrome = abi.decode(data, (IMultihopRouter.UniSwap));
        if (value > 0) velodrome.collectAmount = value;
        else velodrome.collectAmount = (velodrome.collectAmount * newAmount) / oldAmount;
        return (abi.encode(velodrome), velodrome.collectAmount);
    }
}
