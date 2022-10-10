// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../kyberswap/KyberSwapHelper.sol";
import "../../core/libraries/TokenHelper.sol";
import "../../interfaces/IStandardizedYield.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../core/libraries/Errors.sol";

// solhint-disable no-empty-blocks
abstract contract ActionBaseMintRedeem is TokenHelper, KyberSwapHelper {
    using SafeERC20 for IERC20;

    bytes internal constant EMPTY_BYTES = abi.encode();

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter) KyberSwapHelper(_kyberSwapRouter) {}

    /**
     * @notice swap token to baseToken through Uniswap's forks & use it to mint SY
     */
    function _mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) internal returns (uint256 netSyOut) {
        _transferIn(input.tokenIn, msg.sender, input.netTokenIn);
        if (input.tokenIn != input.tokenMintSy) {
            _kyberswap(input.tokenIn, input.netTokenIn, input.kybercall);
        }

        _safeApproveInf(input.tokenMintSy, SY);

        uint256 tokenMintSyBal = _selfBalance(input.tokenMintSy);
        uint256 nativeAmountToAttach = input.tokenMintSy == NATIVE ? tokenMintSyBal : 0;

        netSyOut = IStandardizedYield(SY).deposit{ value: nativeAmountToAttach }(
            receiver,
            input.tokenMintSy,
            tokenMintSyBal,
            minSyOut
        );
    }

    /**
     * @notice redeem SY to baseToken -> swap baseToken to token through Uniswap's forks
     */
    function _redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata output,
        bool doPull
    ) internal returns (uint256 netTokenOut) {
        if (doPull) {
            IERC20(SY).safeTransferFrom(msg.sender, SY, netSyIn);
        }

        if (output.tokenRedeemSy == output.tokenOut) {
            netTokenOut = IStandardizedYield(SY).redeem(
                receiver,
                netSyIn,
                output.tokenRedeemSy,
                output.minTokenOut,
                true
            );
        } else {
            uint256 netTokenRedeemed = IStandardizedYield(SY).redeem(
                address(this),
                netSyIn,
                output.tokenRedeemSy,
                1,
                true
            );
            _kyberswap(output.tokenRedeemSy, netTokenRedeemed, output.kybercall);

            netTokenOut = _selfBalance(output.tokenOut);

            if (netTokenOut < output.minTokenOut)
                revert Errors.RouterInsufficientTokenOut(netTokenOut, output.minTokenOut);

            _transferOut(output.tokenOut, receiver, netTokenOut);
        }
    }

    /**
     * @notice swap token to baseToken through Uniswap's forks -> convert to SY -> convert to PT + YT
     */
    function _mintPyFromToken(
        address receiver,
        address YT,
        uint256 minPyOut,
        TokenInput calldata input
    ) internal returns (uint256 netPyOut) {
        address SY = IPYieldToken(YT).SY();

        _mintSyFromToken(YT, SY, 1, input);

        netPyOut = IPYieldToken(YT).mintPY(receiver, receiver);
        if (netPyOut < minPyOut) revert Errors.RouterInsufficientPYOut(netPyOut, minPyOut);
    }

    /**
     * @notice redeem PT + YT to SY -> redeem SY to baseToken -> swap baseToken to token through Uniswap's forks.
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
        address SY = IPYieldToken(YT).SY();

        if (doPull) {
            bool needToBurnYt = (!IPYieldToken(YT).isExpired());
            IERC20(PT).safeTransferFrom(msg.sender, YT, netPyIn);
            if (needToBurnYt) IERC20(YT).safeTransferFrom(msg.sender, YT, netPyIn);
        }

        uint256 amountSyOut = IPYieldToken(YT).redeemPY(SY); // ignore return

        netTokenOut = _redeemSyToToken(receiver, SY, amountSyOut, output, false);
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
}
