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
                ? _getScaledInputData(data.swapType, data.extCalldata, amountIn)
                : data.extCalldata,
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
    function approveInf(MultiApproval[] calldata arr) external {
        for (uint256 i = 0; i < arr.length; ) {
            MultiApproval calldata ele = arr[i];
            for (uint256 j = 0; j < ele.tokens.length; ) {
                _safeApproveInf(ele.tokens[j], ele.spender);
                unchecked {
                    j++;
                }
            }
            unchecked {
                i++;
            }
        }
    }
}
