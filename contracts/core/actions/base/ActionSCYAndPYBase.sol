// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../libraries/kyberswap/KyberSwapHelper.sol";
import "../../../libraries/helpers/MiniHelpers.sol";
import "../../../libraries/helpers/TokenHelper.sol";
import "../../../interfaces/ISuperComposableYield.sol";
import "../../../interfaces/IPYieldToken.sol";

// solhint-disable no-empty-blocks
abstract contract ActionSCYAndPYBase is TokenHelper, KyberSwapHelper {
    using SafeERC20 for IERC20;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter) KyberSwapHelper(_kyberSwapRouter) {}

    /// @dev for Path. If no swap is needed, path = [token]
    /// else, path = [inputToken, token0, token1, ...., outputToken]

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
        netScyOut = ISuperComposableYield(SCY).deposit{
            value: input.tokenIn == NATIVE ? msg.value : 0
        }(receiver, input.tokenMintScy, _selfBalance(input.tokenMintScy), minScyOut);
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
            netTokenOut = ISuperComposableYield(SCY).redeemAfterTransfer(
                receiver,
                output.tokenRedeemScy,
                output.minTokenOut
            );
        } else {
            uint256 netTokenRedeemed = ISuperComposableYield(SCY).redeemAfterTransfer(
                address(this),
                output.tokenRedeemScy,
                1
            );
            _kyberswap(output.tokenRedeemScy, netTokenRedeemed, output.kybercall);

            netTokenOut = _selfBalance(output.tokenOut);
            require(netTokenOut >= output.minTokenOut, "insufficient out");

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
        require(netPyOut >= minPyOut, "insufficient PY out");
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
        require(netPyOut >= minPyOut, "insufficient PY out");
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
        require(netScyOut >= minScyOut, "insufficient SCY out");
    }
}
