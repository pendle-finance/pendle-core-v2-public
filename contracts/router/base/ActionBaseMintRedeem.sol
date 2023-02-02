// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../core/libraries/TokenHelper.sol";
import "../../interfaces/IStandardizedYield.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPBulkSeller.sol";
import "../../core/libraries/Errors.sol";
import "../swap-aggregator/IPSwapAggregator.sol";

struct TokenInput {
    // Token/Sy data
    address tokenIn;
    uint256 netTokenIn;
    address tokenMintSy;
    address bulk;
    // aggregator data
    address pendleSwap;
    SwapData data;
}

struct TokenOutput {
    // Token/Sy data
    address tokenOut;
    uint256 minTokenOut;
    address tokenRedeemSy;
    address bulk;
    // aggregator data
    address pendleSwap;
    SwapData data;
}

// solhint-disable no-empty-blocks
abstract contract ActionBaseMintRedeem is TokenHelper {
    bytes internal constant EMPTY_BYTES = abi.encode();

    function _mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) internal returns (uint256 netSyOut) {
        bool requireSwap = input.tokenIn != input.tokenMintSy;

        uint256 netTokenMintSy;

        if (input.tokenIn != NATIVE) {
            _transferFrom(
                IERC20(input.tokenIn),
                msg.sender,
                requireSwap ? input.pendleSwap : address(this),
                input.netTokenIn
            );
        }

        if (requireSwap) {
            // doesn't need scaling because we swap exactly the amount pulled in
            IPSwapAggregator(input.pendleSwap).swap{
                value: input.tokenIn == NATIVE ? input.netTokenIn : 0
            }(input.tokenIn, input.netTokenIn, false, input.data);

            netTokenMintSy = _selfBalance(input.tokenMintSy);
        } else {
            netTokenMintSy = input.netTokenIn;
        }

        uint256 netNative = input.tokenMintSy == NATIVE ? netTokenMintSy : 0;

        if (input.bulk != address(0)) {
            netSyOut = IPBulkSeller(input.bulk).swapExactTokenForSy{ value: netNative }(
                receiver,
                netTokenMintSy,
                minSyOut
            );
        } else {
            netSyOut = IStandardizedYield(SY).deposit{ value: netNative }(
                receiver,
                input.tokenMintSy,
                netTokenMintSy,
                minSyOut
            );
        }
    }

    function _redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata output,
        bool doPull
    ) internal returns (uint256 netTokenOut) {
        if (doPull) {
            _transferFrom(IERC20(SY), msg.sender, _syOrBulk(SY, output), netSyIn);
        }

        bool requireSwap = output.tokenRedeemSy != output.tokenOut;
        address receiverRedeemSy = requireSwap ? output.pendleSwap : receiver;
        uint256 netTokenRedeemed;

        if (output.bulk != address(0)) {
            netTokenRedeemed = IPBulkSeller(output.bulk).swapExactSyForToken(
                receiverRedeemSy,
                netSyIn,
                0,
                true
            );
        } else {
            netTokenRedeemed = IStandardizedYield(SY).redeem(
                receiverRedeemSy,
                netSyIn,
                output.tokenRedeemSy,
                0,
                true
            );
        }

        if (requireSwap) {
            IPSwapAggregator(output.pendleSwap).swap{
                value: output.tokenRedeemSy == NATIVE ? netTokenRedeemed : 0
            }(output.tokenRedeemSy, netTokenRedeemed, true, output.data);

            netTokenOut = _selfBalance(output.tokenOut);

            _transferOut(output.tokenOut, receiver, netTokenOut);
        } else {
            netTokenOut = netTokenRedeemed;
        }

        if (netTokenOut < output.minTokenOut) {
            revert Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut);
        }
    }

    function _mintPyFromSy(
        address receiver,
        address SY,
        address YT,
        uint256 netSyIn,
        uint256 minPyOut,
        bool doPull
    ) internal returns (uint256 netPyOut) {
        if (doPull) {
            _transferFrom(IERC20(SY), msg.sender, YT, netSyIn);
        }

        netPyOut = IPYieldToken(YT).mintPY(receiver, receiver);
        if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut);
    }

    function _redeemPyToSy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minSyOut
    ) internal returns (uint256 netSyOut) {
        address PT = IPYieldToken(YT).PT();

        _transferFrom(IERC20(PT), msg.sender, YT, netPyIn);

        bool needToBurnYt = (!IPYieldToken(YT).isExpired());
        if (needToBurnYt) _transferFrom(IERC20(YT), msg.sender, YT, netPyIn);

        netSyOut = IPYieldToken(YT).redeemPY(receiver);
        if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut);
    }

    function _syOrBulk(address SY, TokenOutput calldata output)
        internal
        pure
        returns (address addr)
    {
        return output.bulk != address(0) ? output.bulk : SY;
    }
}
