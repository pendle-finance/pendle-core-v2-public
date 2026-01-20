// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IPActionCrossChain, TokenOutput} from "../interfaces/IPActionCrossChain.sol";
import {IPFixedPricePTAMM} from "../interfaces/IPFixedPricePTAMM.sol";
import {ActionBase} from "./base/ActionBase.sol";
import {IPSwapAggregator, SwapType} from "./swap-aggregator/IPSwapAggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ActionCrossChain is ActionBase, IPActionCrossChain {
    function swapWithFixedPricePTAMM(
        address receiver,
        address fixedPricePTAMM,
        address PT,
        uint256 exactPtIn,
        TokenOutput calldata out
    ) external returns (uint256 netTokenOut) {
        _transferFrom(IERC20(PT), msg.sender, fixedPricePTAMM, exactPtIn);
        uint256 tokenOut = IPFixedPricePTAMM(fixedPricePTAMM)
            .swapExactPtForToken(__swapDestination(receiver, out), PT, exactPtIn, out.tokenRedeemSy, EMPTY_BYTES);
        return __handleTokenOutput(receiver, tokenOut, out);
    }

    /// @notice __swapDestination and __handleTokenOutput provide an alternative way to implement __redeemSyToToken
    /// ```solidity
    /// SwapType swapType = out.swapData.swapType;
    /// address redeemSyReceiver = __swapDestination(receiver, out);
    /// uint256 netTokenRedeemed = __redeemSy(redeemSyReceiver, SY, netSyIn, out, doPull);
    /// return __handleTokenOutput(receiver, netTokenRedeemed, out);
    /// ```
    /// We keep the old implementation of __redeemSyToToken as a stable implementation
    function __swapDestination(address receiver, TokenOutput calldata out) internal view returns (address) {
        SwapType swapType = out.swapData.swapType;
        if (swapType == SwapType.NONE) return receiver;
        else if (swapType == SwapType.ETH_WETH) return address(this);
        else return out.pendleSwap;
    }

    /// @dev The caller must ensure that the address returned by `__swapDestination(...)` has `netTokenRedeemSy` amount
    /// of `out.tokenRedeemSy` tokens before calling this function.
    function __handleTokenOutput(address receiver, uint256 netTokenRedeemSy, TokenOutput calldata out)
        internal
        returns (uint256 netTokenOut)
    {
        SwapType swapType = out.swapData.swapType;
        if (swapType == SwapType.NONE) {
            netTokenOut = netTokenRedeemSy;
        } else if (swapType == SwapType.ETH_WETH) {
            netTokenOut = netTokenRedeemSy; // ETH:WETH is 1:1
            _wrap_unwrap_ETH(out.tokenRedeemSy, out.tokenOut, netTokenOut);
            _transferOut(out.tokenOut, receiver, netTokenOut);
        } else {
            IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemSy, out.swapData);
            netTokenOut = _selfBalance(out.tokenOut);
            _transferOut(out.tokenOut, receiver, netTokenOut);
        }
        if (netTokenOut < out.minTokenOut) revert("Slippage: INSUFFICIENT_TOKEN_OUT");
    }
}
