// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../core/libraries/TokenHelper.sol";
import "./IPSwapAggregator.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./OKXScaleHelper.sol";
import "./OneInchScaleHelper.sol";

contract PendleSwap is IPSwapAggregator, TokenHelper, OKXScaleHelper, OneInchScaleHelper {
    using Address for address;
    using SafeERC20 for IERC20;

    address private constant KYBER_SCALING_HELPER = 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D;

    function swap(address tokenIn, uint256 amountIn, SwapData calldata data) external payable {
        _approveForExtRouter(tokenIn, data);
        data.extRouter.functionCallWithValue(
            data.needScale ? _getScaledInputData(data.swapType, data.extCalldata, amountIn) : data.extCalldata,
            tokenIn == NATIVE ? amountIn : 0
        );

        emit SwapSingle(data.swapType, tokenIn, amountIn);
    }

    function _approveForExtRouter(address token, SwapData calldata data) internal {
        if (token == NATIVE) return;

        if (data.swapType == SwapType.OKX) {
            _safeApproveInfV2(IERC20(token), _okx_getTokenApprove());
        } else {
            _safeApproveInfV2(IERC20(token), data.extRouter);
        }
    }

    function _safeApproveInfV2(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) < type(uint256).max) {
            token.forceApprove(spender, type(uint256).max);
        }
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
        } else if (swapType == SwapType.OKX) {
            scaledCallData = _okxScaling(rawCallData, amountIn);
        } else if (swapType == SwapType.ONE_INCH) {
            scaledCallData = _oneInchScaling(rawCallData, amountIn);
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
