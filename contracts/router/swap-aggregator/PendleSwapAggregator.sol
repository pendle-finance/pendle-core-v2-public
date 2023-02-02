// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";
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
        bool needScale,
        SwapData calldata swapData
    ) external payable {
        swapData.extRouter.functionCallWithValue(
            needScale
                ? _getScaledInputData(swapData.aggregatorType, swapData.extCallData, amountIn)
                : swapData.extCallData,
            tokenIn == NATIVE ? amountIn : 0
        );
    }

    function _getScaledInputData(
        AggregatorType aggregatorType,
        bytes calldata rawCallData,
        uint256 amountIn
    ) internal pure returns (bytes memory scaledCallData) {
        if (aggregatorType == AggregatorType.KYBERSWAP) {
            scaledCallData = _getKyberScaledInputData(rawCallData, amountIn);
        } else if (aggregatorType == AggregatorType.ONE_INCH) {
            scaledCallData = _get1inchScaledInputData(rawCallData, amountIn);
        } else {
            assert(false);
        }
    }

    function approveInf(address token, address spender) external {
        _safeApproveInf(token, spender);
    }
}
