// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../core/libraries/TokenHelper.sol";
import "./IPSwapAggregator.sol";
import "./OKXScaleHelper.sol";
import "./ParaswapScaleHelper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../core/libraries/BoringOwnableUpgradeableV2.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract PendleSwap is
    IPSwapAggregator,
    TokenHelper,
    OKXScaleHelper,
    ParaswapScaleHelper,
    BoringOwnableUpgradeableV2,
    UUPSUpgradeable
{
    using Address for address;
    using SafeERC20 for IERC20;

    address private constant KYBER_SCALING_HELPER = 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D;
    address public immutable REFUND_RECEIVER;

    constructor(bool okx_allowUnsupportedChain, address refundReceiver) OKXScaleHelper(okx_allowUnsupportedChain) {
        _disableInitializers();
        REFUND_RECEIVER = refundReceiver;
    }

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function swap(address tokenIn, uint256 amountIn, SwapData calldata data) external payable {
        _approveForExtRouter(tokenIn, data);
        if (data.swapType == SwapType.ZEROX) {
            _zeroExSwap(tokenIn, amountIn, data);
        } else {
            data.extRouter
                .functionCallWithValue(
                    data.needScale ? _getScaledInputData(data.swapType, data.extCalldata, amountIn) : data.extCalldata,
                    tokenIn == NATIVE ? amountIn : 0
                );
        }

        _transferOut(tokenIn, REFUND_RECEIVER, _balanceOf(address(this), tokenIn));

        emit SwapSingle(data.swapType, tokenIn, amountIn);
    }

    /// @dev extCalldata = abi.encode(tokenOut, quotedAmountIn, quotedMinOut, execCalldata), where execCalldata is the
    /// 0x AllowanceHolder.exec calldata, quoted with sellEntireBalance and the taker as recipient. 0x's own minBuyAmount
    /// is a fixed number, so it is only a backstop. The binding minimum is enforced here, scaled to the actual amountIn
    /// if needScale. The output is forwarded to msg.sender.
    function _zeroExSwap(address tokenIn, uint256 amountIn, SwapData calldata data) internal {
        (address tokenOut, uint256 quotedAmountIn, uint256 quotedMinOut, bytes memory execCalldata) =
            abi.decode(data.extCalldata, (address, uint256, uint256, bytes));

        uint256 balBefore = _selfBalance(tokenOut);
        data.extRouter.functionCallWithValue(execCalldata, tokenIn == NATIVE ? amountIn : 0);
        uint256 netOut = _selfBalance(tokenOut) - balBefore;

        uint256 minOut = data.needScale ? (quotedMinOut * amountIn) / quotedAmountIn : quotedMinOut;
        require(netOut >= minOut, "PendleSwap: 0x insufficient out");

        _transferOut(tokenOut, msg.sender, netOut);
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

    function _getScaledInputData(SwapType swapType, bytes calldata rawCallData, uint256 amountIn)
        internal
        view
        returns (bytes memory scaledCallData)
    {
        if (swapType == SwapType.KYBERSWAP) {
            bool isSuccess;
            (isSuccess, scaledCallData) =
                IKyberScalingHelper(KYBER_SCALING_HELPER).getScaledInputData(rawCallData, amountIn);

            require(isSuccess, "PendleSwap: Kyber scaling failed");
        } else if (swapType == SwapType.PARASWAP) {
            scaledCallData = _paraswapScaling(rawCallData, amountIn);
        } else if (swapType == SwapType.OKX) {
            scaledCallData = _okxScaling(rawCallData, amountIn);
        } else {
            assert(false);
        }
    }

    receive() external payable {}

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}
}

interface IKyberScalingHelper {
    function getScaledInputData(bytes calldata inputData, uint256 newAmount)
        external
        view
        returns (bool isSuccess, bytes memory data);
}
