// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGenericSwapExactAmountIn {
    struct GenericData {
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
    }

    function swapExactAmountIn(
        address executor,
        GenericData calldata swapData,
        uint256 partnerAndFee,
        bytes calldata permit,
        bytes calldata executorData
     ) external payable;
}

contract ParaswapScaleHelper {

    function _paraswapScaling(
        bytes calldata rawCallData,
        uint256 amountIn
    ) internal pure returns (bytes memory scaledCallData) {
        bytes4 selector = bytes4(rawCallData[:4]);
        bytes calldata dataToDecode = rawCallData[4:];

        assert(selector == IGenericSwapExactAmountIn.swapExactAmountIn.selector);
        (
            address executor,
            IGenericSwapExactAmountIn.GenericData memory swapData,
            uint256 partnerAndFee,
            bytes memory permit,
            bytes memory executorData
        ) = abi.decode(dataToDecode, (address, IGenericSwapExactAmountIn.GenericData, uint256, bytes, bytes));

        // Scale the amounts proportionally
        uint256 scaleFactor = amountIn * 1e18 / swapData.fromAmount;
        swapData.fromAmount = amountIn;
        swapData.toAmount = (swapData.toAmount * scaleFactor) / 1e18;
        swapData.quotedAmount = (swapData.quotedAmount * scaleFactor) / 1e18;

        return abi.encodeWithSelector(selector, executor, swapData, partnerAndFee, permit, executorData);
    }
} 