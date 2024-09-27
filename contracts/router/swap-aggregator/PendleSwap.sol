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
        } else {
            assert(false);
        }
    }

    receive() external payable {}
}

interface IKyberScalingHelper {
    function getScaledInputData(
        bytes calldata inputData,
        uint256 newAmount
    ) external view returns (bool isSuccess, bytes memory data);
}
