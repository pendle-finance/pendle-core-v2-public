// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../libraries/traderjoe/PendleJoeSwapHelperUpg.sol";
import "../../../libraries/helpers/MiniHelpers.sol";
import "../../../libraries/helpers/TokenHelper.sol";
import "../../../interfaces/ISuperComposableYield.sol";
import "../../../interfaces/IPYieldToken.sol";

// solhint-disable no-empty-blocks
abstract contract ActionSCYAndPYBase is PendleJoeSwapHelperUpg, TokenHelper {
    using SafeERC20 for IERC20;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _joeFactory) PendleJoeSwapHelperUpg(_joeFactory) {}

    /// @dev for Path. If no swap is needed, path = [token]
    /// else, path = [inputToken, token0, token1, ...., outputToken]

    /**
     * @notice swap rawToken to baseToken through Uniswap's forks & use it to mint SCY
     */
    function _mintScyFromRawToken(
        address receiver,
        address SCY,
        uint256 netRawTokenIn,
        uint256 minScyOut,
        address[] calldata path,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        uint256 amountBaseToken;
        if (path.length == 1) {
            if (doPull) {
                IERC20(path[0]).safeTransferFrom(msg.sender, address(this), netRawTokenIn);
            }
            amountBaseToken = netRawTokenIn;
        } else {
            if (doPull) {
                IERC20(path[0]).safeTransferFrom(msg.sender, _getFirstPair(path), netRawTokenIn);
            }
            amountBaseToken = _swapExactIn(path, netRawTokenIn, address(this));
        }

        address baseToken = path[path.length - 1];
        IERC20(baseToken).approve(SCY, amountBaseToken);
        netScyOut = ISuperComposableYield(SCY).deposit(
            receiver,
            baseToken,
            amountBaseToken,
            minScyOut
        );
    }

    /**
     * @notice redeem SCY to baseToken -> swap baseToken to rawToken through Uniswap's forks
     */
    function _redeemScyToRawToken(
        address receiver,
        address SCY,
        uint256 netScyIn,
        uint256 minRawTokenOut,
        address[] memory path,
        bool doPull
    ) internal returns (uint256 netRawTokenOut) {
        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, SCY, netScyIn);
        }

        address baseToken = path[0];
        if (path.length == 1) {
            netRawTokenOut = ISuperComposableYield(SCY).redeemAfterTransfer(
                receiver,
                baseToken,
                minRawTokenOut
            );
        } else {
            uint256 netBaseTokenOut = ISuperComposableYield(SCY).redeemAfterTransfer(
                _getFirstPair(path),
                baseToken,
                1
            );
            netRawTokenOut = _swapExactIn(path, netBaseTokenOut, receiver);
            require(netRawTokenOut >= minRawTokenOut, "insufficient out");
        }
    }

    /**
     * @notice swap rawToken to baseToken through Uniswap's forks -> convert to SCY -> convert to PT + YT
     */
    function _mintPyFromRawToken(
        address receiver,
        address YT,
        uint256 netRawTokenIn,
        uint256 minPyOut,
        address[] calldata path,
        bool doPull
    ) internal returns (uint256 netPyOut) {
        address SCY = IPYieldToken(YT).SCY();

        _mintScyFromRawToken(YT, SCY, netRawTokenIn, 1, path, doPull);

        netPyOut = IPYieldToken(YT).mintPY(receiver, receiver);
        require(netPyOut >= minPyOut, "insufficient PY out");
    }

    /**
     * @notice redeem PT + YT to SCY -> redeem SCY to baseToken -> swap baseToken to rawToken through Uniswap's forks.
        If the YT hasn't expired, both PT & YT will be needed to redeem. Else, only PT is needed
     */
    function _redeemPyToRawToken(
        address receiver,
        address YT,
        uint256 netPyIn,
        uint256 minRawTokenOut,
        address[] memory path,
        bool doPull
    ) internal returns (uint256 netRawTokenOut) {
        address PT = IPYieldToken(YT).PT();
        address SCY = IPYieldToken(YT).SCY();

        if (doPull) {
            bool needToBurnYt = (!IPYieldToken(YT).isExpired());
            IERC20(PT).safeTransferFrom(msg.sender, YT, netPyIn);
            if (needToBurnYt) IERC20(YT).safeTransferFrom(msg.sender, YT, netPyIn);
        }

        IPYieldToken(YT).redeemPY(SCY); // ignore return

        netRawTokenOut = _redeemScyToRawToken(receiver, SCY, 0, minRawTokenOut, path, false);
    }
}
