// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "../misc/PendleJoeSwapHelper.sol";
import "../../LiquidYieldToken/ILiquidYieldToken.sol";

contract PendleRouterForge is PendleJoeSwapHelper {
    using SafeERC20 for IERC20;

    constructor(address _joeRouter, address _joeFactory)
        PendleJoeSwapHelper(_joeRouter, _joeFactory)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    function swapExactRawTokenForLYT(
        uint256 amountRawTokenIn,
        address LYT,
        uint256 minAmountLYTOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 amountLYTOut) {
        if (path.length == 1) {
            IERC20(path[0]).transferFrom(msg.sender, LYT, amountRawTokenIn);
        } else {
            IERC20(path[0]).transferFrom(msg.sender, _getFirstPair(path), amountRawTokenIn);
            _swapExactIn(path, amountRawTokenIn, LYT);
        }

        amountLYTOut = _swapExactRawTokenForLYT(LYT, minAmountLYTOut, recipient, path);
    }

    function _swapExactRawTokenForLYT(
        address LYT,
        uint256 minAmountLYTOut,
        address recipient,
        address[] calldata path
    ) internal returns (uint256 amountLYTOut) {
        address baseToken = path[path.length - 1];
        amountLYTOut = ILiquidYieldToken(LYT).depositBaseToken(
            recipient,
            baseToken,
            minAmountLYTOut
        );
    }

    function swapExactLYTToRawToken(
        address LYT,
        uint256 amountLYTIn,
        uint256 minAmountRawTokenOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 amountRawTokenOut) {
        IERC20(LYT).safeTransferFrom(msg.sender, LYT, amountLYTIn);
        amountRawTokenOut = _swapExactLYTToRawToken(LYT, minAmountRawTokenOut, recipient, path);
    }

    function _swapExactLYTToRawToken(
        address LYT,
        uint256 minAmountRawTokenOut,
        address recipient,
        address[] calldata path
    ) internal returns (uint256 amountRawTokenOut) {
        address baseToken = path[0];
        if (path.length == 1) {
            amountRawTokenOut = ILiquidYieldToken(LYT).redeemToBaseToken(
                recipient,
                baseToken,
                minAmountRawTokenOut
            );
        } else {
            amountRawTokenOut = ILiquidYieldToken(LYT).redeemToBaseToken(
                _getFirstPair(path),
                baseToken,
                minAmountRawTokenOut
            );
            _swapExactIn(path, amountRawTokenOut, recipient);
        }
    }
}
