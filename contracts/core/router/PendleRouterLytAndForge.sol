// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "../misc/PendleJoeSwapHelper.sol";
import "../../LiquidYieldToken/ILiquidYieldToken.sol";

contract PendleRouterLytAndForge is PendleJoeSwapHelper {
    using SafeERC20 for IERC20;

    constructor(address _joeRouter, address _joeFactory)
        PendleJoeSwapHelper(_joeRouter, _joeFactory)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function mintLytFromRawToken(
        uint256 netRawTokenIn,
        address LYT,
        uint256 minLytOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 netLYTOut) {
        if (path.length == 1) {
            IERC20(path[0]).transferFrom(msg.sender, LYT, netRawTokenIn);
        } else {
            IERC20(path[0]).transferFrom(msg.sender, _getFirstPair(path), netRawTokenIn);
            _swapExactIn(path, netRawTokenIn, LYT);
        }

        netLYTOut = _mintLytFromRawToken(LYT, minLytOut, recipient, path);
    }

    function redeemLYTToRawToken(
        address LYT,
        uint256 netLytIn,
        uint256 minRawTokenOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 netRawTokenOut) {
        IERC20(LYT).safeTransferFrom(msg.sender, LYT, netLytIn);
        netRawTokenOut = _redeemLYTToRawToken(LYT, minRawTokenOut, recipient, path);
    }

    function _mintLytFromRawToken(
        address LYT,
        uint256 minLytOut,
        address recipient,
        address[] calldata path
    ) internal returns (uint256 netLYTOut) {
        address baseToken = path[path.length - 1];
        netLYTOut = ILiquidYieldToken(LYT).mint(recipient, baseToken, minLytOut);
    }

    function _redeemLYTToRawToken(
        address LYT,
        uint256 minRawTokenOut,
        address recipient,
        address[] calldata path
    ) internal returns (uint256 netRawTokenOut) {
        address baseToken = path[0];
        if (path.length == 1) {
            netRawTokenOut = ILiquidYieldToken(LYT).redeem(recipient, baseToken, minRawTokenOut);
        } else {
            netRawTokenOut = ILiquidYieldToken(LYT).redeem(
                _getFirstPair(path),
                baseToken,
                minRawTokenOut
            );
            _swapExactIn(path, netRawTokenOut, recipient);
        }
    }
}
