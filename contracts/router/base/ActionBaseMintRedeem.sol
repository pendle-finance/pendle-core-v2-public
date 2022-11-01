// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../kyberswap/KyberSwapHelper.sol";
import "../../core/libraries/TokenHelper.sol";
import "../../interfaces/IStandardizedYield.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPBulkSeller.sol";
import "../../core/libraries/Errors.sol";

// solhint-disable no-empty-blocks
abstract contract ActionBaseMintRedeem is TokenHelper, KyberSwapHelper {
    bytes internal constant EMPTY_BYTES = abi.encode();

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberScalingLib) KyberSwapHelper(_kyberScalingLib) {}

    function _mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) internal returns (uint256 netSyOut) {
        _transferIn(input.tokenIn, msg.sender, input.netTokenIn);

        bool requireSwap = input.tokenIn != input.tokenMintSy;

        uint256 netTokenMintSy;

        if (requireSwap) {
            _kyberswap(input.tokenIn, input.netTokenIn, input.kyberRouter, input.kybercall);
            netTokenMintSy = _selfBalance(input.tokenMintSy);
        } else {
            netTokenMintSy = input.netTokenIn;
        }

        if (input.bulk != address(0)) {
            _transferOut(input.tokenMintSy, input.bulk, netTokenMintSy);

            netSyOut = IPBulkSeller(input.bulk).swapExactTokenForSy(
                receiver,
                netTokenMintSy,
                minSyOut
            );
        } else {
            uint256 netNative = input.tokenMintSy == NATIVE ? netTokenMintSy : 0;

            _safeApproveInf(input.tokenMintSy, SY);

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
        TokenOutput memory output,
        bool doPull
    ) internal returns (uint256 netTokenOut) {
        if (doPull) {
            _transferFrom(IERC20(SY), msg.sender, _syOrBulk(SY, output), netSyIn);
        }

        bool requireSwap = output.tokenRedeemSy != output.tokenOut;
        address receiverRedeemSy = requireSwap ? address(this) : receiver;
        uint256 netTokenRedeemed;

        if (output.bulk != address(0)) {
            netTokenRedeemed = IPBulkSeller(output.bulk).swapExactSyForToken(
                receiverRedeemSy,
                netSyIn,
                0
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
            _kyberswap(
                output.tokenRedeemSy,
                netTokenRedeemed,
                output.kyberRouter,
                output.kybercall
            );

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
        address YT,
        uint256 netSyIn,
        uint256 minPyOut,
        bool doPull
    ) internal returns (uint256 netPyOut) {
        address SY = IPYieldToken(YT).SY();

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

    function _syOrBulk(address SY, TokenOutput memory output)
        internal
        pure
        returns (address addr)
    {
        return output.bulk != address(0) ? output.bulk : SY;
    }

    function _wrapTokenOutput(
        address tokenOut,
        uint256 minTokenOut,
        address bulk
    ) internal pure returns (TokenOutput memory) {
        return TokenOutput(tokenOut, minTokenOut, tokenOut, bulk, address(0), EMPTY_BYTES);
    }
}
