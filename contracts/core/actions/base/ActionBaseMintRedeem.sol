// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../libraries/kyberswap/KyberSwapHelper.sol";
import "../../../libraries/helpers/TokenHelper.sol";
import "../../../interfaces/ISuperComposableYield.sol";
import "../../../interfaces/IPYieldToken.sol";
import "../../../libraries/Errors.sol";

// solhint-disable no-empty-blocks
abstract contract ActionBaseMintRedeem is TokenHelper, KyberSwapHelper {
    using SafeERC20 for IERC20;

    bytes internal constant EMPTY_BYTES = abi.encode();

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter) KyberSwapHelper(_kyberSwapRouter) {}

    /**
     * @notice swap token to baseToken through Uniswap's forks & use it to mint SCY
     */
    function _mintScyFromToken(
        address receiver,
        address SCY,
        uint256 minScyOut,
        TokenInput calldata input
    ) internal returns (uint256 netScyOut) {
        _transferIn(input.tokenIn, msg.sender, input.netTokenIn);
        if (input.tokenIn != input.tokenMintScy) {
            _kyberswap(input.tokenIn, input.netTokenIn, input.kybercall);
        }

        _safeApproveInf(input.tokenMintScy, SCY);

        uint256 tokenMintScyBal = _selfBalance(input.tokenMintScy);
        uint256 nativeAmountToAttach = input.tokenMintScy == NATIVE ? tokenMintScyBal : 0;

        netScyOut = ISuperComposableYield(SCY).deposit{ value: nativeAmountToAttach }(
            receiver,
            input.tokenMintScy,
            tokenMintScyBal,
            minScyOut
        );
    }

    /**
     * @notice redeem SCY to baseToken -> swap baseToken to token through Uniswap's forks
     */
    function _redeemScyToToken(
        address receiver,
        address SCY,
        uint256 netScyIn,
        TokenOutput calldata output,
        bool doPull
    ) internal returns (uint256 netTokenOut) {
        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, SCY, netScyIn);
        }

        if (output.tokenRedeemScy == output.tokenOut) {
            netTokenOut = ISuperComposableYield(SCY).redeem(
                receiver,
                netScyIn,
                output.tokenRedeemScy,
                output.minTokenOut,
                true
            );
        } else {
            uint256 netTokenRedeemed = ISuperComposableYield(SCY).redeem(
                address(this),
                netScyIn,
                output.tokenRedeemScy,
                1,
                true
            );
            _kyberswap(output.tokenRedeemScy, netTokenRedeemed, output.kybercall);

            netTokenOut = _selfBalance(output.tokenOut);

            if (netTokenOut < output.minTokenOut)
                revert Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut);

            _transferOut(output.tokenOut, receiver, netTokenOut);
        }
    }

    /**
     * @notice swap token to baseToken through Uniswap's forks -> convert to SCY -> convert to PT + YT
     */
    function _mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) internal returns (uint256 netPyOut) {
        address SCY = IPYieldToken(YT).SCY();

        _mintScyFromToken(YT, SCY, 1, input);

        netPyOut = IPYieldToken(YT).mintPY(receiver, receiver);
        if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut);
    }

    /**
     * @notice redeem PT + YT to SCY -> redeem SCY to baseToken -> swap baseToken to token through Uniswap's forks.
        If the YT hasn't expired, both PT & YT will be needed to redeem. Else, only PT is needed
     */
    function _redeemPyToToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        TokenOutput calldata output,
        bool doPull
    ) internal returns (uint256 netTokenOut) {
        address PT = IPYieldToken(YT).PT();
        address SCY = IPYieldToken(YT).SCY();

        if (doPull) {
            bool needToBurnYt = (!IPYieldToken(YT).isExpired());
            IERC20(PT).safeTransferFrom(msg.sender, YT, netPyIn);
            if (needToBurnYt) IERC20(YT).safeTransferFrom(msg.sender, YT, netPyIn);
        }

        uint256 amountScyOut = IPYieldToken(YT).redeemPY(SCY); // ignore return

        netTokenOut = _redeemScyToToken(receiver, SCY, amountScyOut, output, false);
    }

    function _mintPyFromScy(
        address receiver,
        address YT,
        uint256 netScyIn,
        uint256 minPyOut,
        bool doPull
    ) internal returns (uint256 netPyOut) {
        address SCY = IPYieldToken(YT).SCY();

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, YT, netScyIn);
        }

        netPyOut = IPYieldToken(YT).mintPY(receiver, receiver);
        if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut);
    }

    function _redeemPyToScy(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minScyOut,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        address PT = IPYieldToken(YT).PT();

        if (doPull) {
            bool needToBurnYt = (!IPYieldToken(YT).isExpired());
            IERC20(PT).safeTransferFrom(msg.sender, YT, netPyIn);
            if (needToBurnYt) IERC20(YT).safeTransferFrom(msg.sender, YT, netPyIn);
        }

        netScyOut = IPYieldToken(YT).redeemPY(receiver);
        if (netScyOut < minScyOut) revert Errors.RouterInsufficientScyOut(netScyOut, minScyOut);
    }
}
