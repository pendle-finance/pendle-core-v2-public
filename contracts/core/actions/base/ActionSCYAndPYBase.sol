// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../periphery/PendleJoeSwapHelperUpg.sol";
import "../../../interfaces/ISuperComposableYield.sol";
import "../../../interfaces/IPYieldToken.sol";

// solhint-disable no-empty-blocks
abstract contract ActionSCYAndPYBase is PendleJoeSwapHelperUpg {
    using SafeERC20 for IERC20;

    event MintScyFromRawToken(
        address indexed user,
        address indexed rawTokenIn,
        uint256 netRawTokenIn,
        address indexed SCY,
        uint256 netScyOut
    );

    event RedeemScyToRawToken(
        address indexed user,
        address indexed SCY,
        uint256 netScyIn,
        address indexed rawTokenOut,
        uint256 netRawTokenOut
    );

    event MintPyFromRawToken(
        address indexed user,
        address indexed rawTokenIn,
        uint256 netRawTokenIn,
        address indexed YT,
        uint256 netPyOut
    );

    event RedeemPyToRawToken(
        address indexed user,
        address indexed YT,
        uint256 netPyIn,
        address indexed rawTokenOut,
        uint256 netRawTokenOut
    );

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _joeRouter, address _joeFactory)
        PendleJoeSwapHelperUpg(_joeRouter, _joeFactory)
    {}

    /**
     * @notice swap rawToken to baseToken -> baseToken to mint SCY
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - if [rawToken == baseToken], rawToken is transferred to SCY contract
       else, it is transferred to the first pair of path, swap is called, and the output token is transferred
            to SCY contract
     - SCY.mint is called, minting SCY directly to receiver
     */
    function _mintScyFromRawToken(
        uint256 netRawTokenIn,
        address SCY,
        uint256 minScyOut,
        address receiver,
        address[] calldata path,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        if (doPull) {
            if (path.length == 1) {
                IERC20(path[0]).safeTransferFrom(msg.sender, SCY, netRawTokenIn);
            } else {
                IERC20(path[0]).safeTransferFrom(msg.sender, _getFirstPair(path), netRawTokenIn);
                _swapExactIn(path, netRawTokenIn, SCY);
            }
        }

        address baseToken = path[path.length - 1];
        netScyOut = ISuperComposableYield(SCY).deposit(receiver, baseToken, 0, minScyOut);
        emit MintScyFromRawToken(msg.sender, path[0], netRawTokenIn, SCY, netScyOut);
    }

    /**
    * @notice redeem SCY to baseToken -> swap baseToken to rawToken
    * @dev path[0] will be the baseToken that SCY is redeemed to, and path[path.length-1] is the
    final rawToken output
    * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
    * @dev inner working of this function:
     - SCY is transferred to SCY contract
     - if [rawToken == baseToken], SCY.redeem is called & directly redeem tokens to the receiver
       else, SCY.redeem is called with receiver = first pair in the path,
        and swap is called, and the output token is transferred to receiver
     */
    function _redeemScyToRawToken(
        address SCY,
        uint256 netScyIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path,
        bool doPull
    ) internal returns (uint256 netRawTokenOut) {
        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, SCY, netScyIn);
        }

        address baseToken = path[0];
        if (path.length == 1) {
            netRawTokenOut = ISuperComposableYield(SCY).redeem(
                receiver,
                0,
                baseToken,
                minRawTokenOut
            );
        } else {
            uint256 netBaseTokenOut = ISuperComposableYield(SCY).redeem(
                _getFirstPair(path),
                0,
                baseToken,
                1
            );
            netRawTokenOut = _swapExactIn(path, netBaseTokenOut, receiver);
            require(netRawTokenOut >= minRawTokenOut, "insufficient out");
        }

        emit RedeemScyToRawToken(msg.sender, SCY, netScyIn, path[path.length - 1], netRawTokenOut);
    }

    /**
     * @notice swap rawToken to baseToken -> convert to SCY -> convert to PT + YT
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - same as mintScyFromRawToken, except the receiver of SCY will be the YT contract, then mintPY
     will be called, minting PT + YT directly to receiver
     */
    function _mintPyFromRawToken(
        uint256 netRawTokenIn,
        address YT,
        uint256 minPyOut,
        address receiver,
        address[] calldata path,
        bool doPull
    ) internal returns (uint256 netPyOut) {
        address SCY = IPYieldToken(YT).SCY();
        _mintScyFromRawToken(netRawTokenIn, SCY, 1, YT, path, doPull);
        netPyOut = IPYieldToken(YT).mintPY(receiver, receiver);
        require(netPyOut >= minPyOut, "insufficient PY out");
        emit MintPyFromRawToken(msg.sender, path[0], netRawTokenIn, YT, netPyOut);
    }

    /**
     * @notice redeem PT + YT to SCY -> redeem SCY to baseToken -> swap baseToken to rawToken
     * @param path the path to swap from rawToken to baseToken. path = [baseToken] if no swap is needed
     * @dev inner working of this function:
     - PT (+ YT if not expired) is transferred to the YT contract
     - redeemPY is called, redeem all outcome SCY to the SCY contract
     - The rest is the same as redeemScyToRawToken (except the first SCY transfer is skipped)
     */
    function _redeemPyToRawToken(
        address YT,
        uint256 netPyIn,
        uint256 minRawTokenOut,
        address receiver,
        address[] memory path,
        bool doPull
    ) internal returns (uint256 netRawTokenOut) {
        address PT = IPYieldToken(YT).PT();
        address SCY = IPYieldToken(YT).SCY();

        if (doPull) {
            bool isNeedToBurnYt = (!IPBaseToken(YT).isExpired());
            IERC20(PT).safeTransferFrom(msg.sender, YT, netPyIn);
            if (isNeedToBurnYt) IERC20(YT).safeTransferFrom(msg.sender, YT, netPyIn);
        }

        IPYieldToken(YT).redeemPY(SCY); // ignore return

        netRawTokenOut = _redeemScyToRawToken(SCY, 0, minRawTokenOut, receiver, path, false);

        emit RedeemPyToRawToken(msg.sender, YT, netPyIn, path[path.length - 1], netRawTokenOut);
    }
}
