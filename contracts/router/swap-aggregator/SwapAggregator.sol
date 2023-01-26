// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../core/libraries/BoringOwnableUpgradeable.sol";
import "../../core/libraries/TokenHelper.sol";
import "../../core/libraries/Errors.sol";
import "./ISwapAggregator.sol";
import "./1inch/OneInchAggregationRouterHelper.sol";
import "./kyberswap/KyberAggregationRouterHelper.sol";

contract SwapAggregator is
    ISwapAggregator,
    TokenHelper,
    KyberAggregationRouterHelper,
    OneInchAggregationRouterHelper,
    Initializable,
    UUPSUpgradeable,
    BoringOwnableUpgradeable
{
    using Address for address;

    constructor() initializer {}

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function swap(
        address tokenIn,
        uint256 amountIn,
        SwapData calldata swapData
    ) external payable {
        _safeApproveInf(tokenIn, swapData.router);
        bytes memory scaledCallData = _getScaledInputData(
            swapData.aggregatorType,
            swapData.callData,
            amountIn
        );

        swapData.router.functionCallWithValue(scaledCallData, tokenIn == NATIVE ? amountIn : 0);
    }

    function _getScaledInputData(
        AGGREGATOR aggregatorType,
        bytes calldata rawCallData,
        uint256 amountIn
    ) internal pure returns (bytes memory scaledCallData) {
        if (aggregatorType == AGGREGATOR.KYBERSWAP) {
            scaledCallData = _getKyberScaledInputData(rawCallData, amountIn);
        } else if (aggregatorType == AGGREGATOR.ONE_INCH) {
            scaledCallData = _get1inchScaledInputData(rawCallData, amountIn);
        } else {
            assert(false);
        }
    }

    // ====================== UPGRADE ======================

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}
}
