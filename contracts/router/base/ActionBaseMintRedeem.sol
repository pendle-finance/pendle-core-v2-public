// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../kyberswap/KyberSwapHelper.sol";
import "../../core/libraries/TokenHelper.sol";
import "../../interfaces/IStandardizedYield.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPBulkSellerDirectory.sol";
import "../../interfaces/IPBulkSeller.sol";
import "../../core/libraries/Errors.sol";

// solhint-disable no-empty-blocks
abstract contract ActionBaseMintRedeem is TokenHelper, KyberSwapHelper {
    using SafeERC20 for IERC20;

    bytes internal constant EMPTY_BYTES = abi.encode();
    IPBulkSellerDirectory public immutable bulkDir;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter, address _bulkSellerDirectory)
        KyberSwapHelper(_kyberSwapRouter)
    {
        bulkDir = IPBulkSellerDirectory(_bulkSellerDirectory);
    }

    function _mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) internal returns (uint256 netSyOut) {
        _transferIn(input.tokenIn, msg.sender, input.netTokenIn);

        bool requireSwap = input.tokenIn != input.tokenMintSy;
        if (requireSwap) {
            _kyberswap(input.tokenIn, input.netTokenIn, input.kybercall);
        }

        uint256 tokenMintSyBal = _selfBalance(input.tokenMintSy);
        if (input.useBulk) {
            address bulk = bulkDir.get(input.tokenMintSy, SY);

            _transferOut(input.tokenMintSy, bulk, tokenMintSyBal);

            netSyOut = IPBulkSeller(bulk).swapExactTokenForSy(receiver, tokenMintSyBal, minSyOut);
        } else {
            uint256 netNative = input.tokenMintSy == NATIVE ? tokenMintSyBal : 0;

            _safeApproveInf(input.tokenMintSy, SY);

            netSyOut = IStandardizedYield(SY).deposit{ value: netNative }(
                receiver,
                input.tokenMintSy,
                tokenMintSyBal,
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
            IERC20(SY).safeTransferFrom(msg.sender, _syOrBulk(SY, output), netSyIn);
        }

        bool requireSwap = output.tokenRedeemSy != output.tokenOut;
        address receiverRedeemSy = requireSwap ? address(this) : receiver;
        uint256 netTokenRedeemed;

        if (output.useBulk) {
            address bulk = bulkDir.get(output.tokenRedeemSy, SY);
            netTokenRedeemed = IPBulkSeller(bulk).swapExactSyForToken(
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
            _kyberswap(output.tokenRedeemSy, netTokenRedeemed, output.kybercall);

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
            IERC20(SY).safeTransferFrom(msg.sender, YT, netSyIn);
        }

        netPyOut = IPYieldToken(YT).mintPY(receiver, receiver);
        if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut);
    }

    function _redeemPyToSy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minSyOut,
        bool doPull
    ) internal returns (uint256 netSyOut) {
        address PT = IPYieldToken(YT).PT();

        if (doPull) {
            bool needToBurnYt = (!IPYieldToken(YT).isExpired());
            IERC20(PT).safeTransferFrom(msg.sender, YT, netPyIn);
            if (needToBurnYt) IERC20(YT).safeTransferFrom(msg.sender, YT, netPyIn);
        }

        netSyOut = IPYieldToken(YT).redeemPY(receiver);
        if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut);
    }

    function _syOrBulk(address SY, TokenOutput memory output)
        internal
        view
        returns (address addr)
    {
        return (output.useBulk ? bulkDir.get(output.tokenRedeemSy, SY) : SY);
    }

    function _wrapTokenOutput(
        address tokenOut,
        uint256 minTokenOut,
        bool useBulk
    ) internal pure returns (TokenOutput memory) {
        return TokenOutput(tokenOut, minTokenOut, tokenOut, EMPTY_BYTES, useBulk);
    }
}
