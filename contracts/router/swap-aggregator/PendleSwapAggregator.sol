// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../interfaces/IWETH.sol";
import "../../core/libraries/TokenHelper.sol";
import "../../core/libraries/Errors.sol";
import "./IPSwapAggregator.sol";
import "./1inch/OneInchAggregationRouterHelper.sol";
import "./kyberswap/KyberAggregationRouterHelper.sol";

contract PendleSwapAggregator is
    IPSwapAggregator,
    TokenHelper,
    KyberAggregationRouterHelper,
    OneInchAggregationRouterHelper
{
    using Address for address;

    function swap(
        address tokenIn,
        uint256 amountIn,
        SwapData calldata data
    ) external payable {
        data.extRouter.functionCallWithValue(
            data.needScale
                ? _getScaledInputData(data.swapType, data.extCallData, amountIn)
                : data.extCallData,
            tokenIn == NATIVE ? amountIn : 0
        );
    }

    function _getScaledInputData(
        SwapType swapType,
        bytes calldata rawCallData,
        uint256 amountIn
    ) internal pure returns (bytes memory scaledCallData) {
        if (swapType == SwapType.KYBERSWAP) {
            scaledCallData = _getKyberScaledInputData(rawCallData, amountIn);
        } else if (swapType == SwapType.ONE_INCH) {
            scaledCallData = _get1inchScaledInputData(rawCallData, amountIn);
        } else {
            assert(false);
        }
    }

    /// @notice For the Aggregator to work with a token / aggregator, it must be approved first
    function approveInf(address[] calldata tokens, address[] calldata spenders) external {
        if (tokens.length != spenders.length) revert Errors.ArrayLengthMismatch();

        for (uint256 i = 0; i < tokens.length; ) {
            _safeApproveInf(tokens[i], spenders[i]);
            unchecked {
                i++;
            }
        }
    }
}
