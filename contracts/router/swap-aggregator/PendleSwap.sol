// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../core/libraries/TokenHelper.sol";
import "./IPSwapAggregator.sol";
import "./kyberswap/l1-contracts/InputScalingHelper.sol";
import "./kyberswap/l2-contracts/InputScalingHelperL2.sol";

contract PendleSwap is IPSwapAggregator, TokenHelper {
    using Address for address;

    address public immutable KYBER_SCALING_HELPER = 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D;

    function swap(address tokenIn, uint256 amountIn, SwapData calldata data) external payable {
        _safeApproveInf(tokenIn, data.extRouter);
        data.extRouter.functionCallWithValue(
            data.needScale ? _getScaledInputData(data.swapType, data.extCalldata, amountIn) : data.extCalldata,
            tokenIn == NATIVE ? amountIn : 0
        );

        emit SwapSingle(data.swapType, tokenIn, amountIn);
    }

    function swapMultiOdos(address[] calldata tokensIn, SwapData calldata data) external payable {
        for (uint256 i = 0; i < tokensIn.length; ++i) {
            _safeApproveInf(tokensIn[i], data.extRouter);
        }
        data.extRouter.functionCallWithValue(data.extCalldata, msg.value);
    }

    function _getScaledInputData(
        SwapType swapType,
        bytes calldata rawCallData,
        uint256 amountIn
    ) internal view returns (bytes memory scaledCallData) {
        if (swapType == SwapType.KYBERSWAP) {
            bool isSuccess;
            (isSuccess, scaledCallData) = IKyberScalingHelper(KYBER_SCALING_HELPER).getScaledInputData(
                rawCallData,
                amountIn
            );

            require(isSuccess, "PendleSwap: Kyber scaling failed");
        } else if (swapType == SwapType.ODOS) {
            scaledCallData = _odosScaling(rawCallData, amountIn);
        } else {
            assert(false);
        }
    }

    function _odosScaling(
        bytes calldata rawCallData,
        uint256 amountIn
    ) internal pure returns (bytes memory scaledCallData) {
        bytes4 selector = bytes4(rawCallData[:4]);
        bytes calldata dataToDecode = rawCallData[4:];

        assert(selector == IOdosRouterV2.swap.selector);
        (
            IOdosRouterV2.swapTokenInfo memory tokenInfo,
            bytes memory pathDefinition,
            address executor,
            uint32 referralCode
        ) = abi.decode(dataToDecode, (IOdosRouterV2.swapTokenInfo, bytes, address, uint32));

        tokenInfo.outputQuote = (tokenInfo.outputQuote * amountIn) / tokenInfo.inputAmount;
        tokenInfo.outputMin = (tokenInfo.outputMin * amountIn) / tokenInfo.inputAmount;
        tokenInfo.inputAmount = amountIn;

        return abi.encodeWithSelector(selector, tokenInfo, pathDefinition, executor, referralCode);
    }

    receive() external payable {}
}

interface IKyberScalingHelper {
    function getScaledInputData(
        bytes calldata inputData,
        uint256 newAmount
    ) external view returns (bool isSuccess, bytes memory data);
}

interface IOdosRouterV2 {
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    function swap(
        swapTokenInfo memory tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external payable returns (uint256 amountOut);
}
