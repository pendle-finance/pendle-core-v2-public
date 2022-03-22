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
        address rawToken,
        uint256 amountRawTokenIn,
        address baseToken,
        address LYT,
        uint256 minAmountLYTOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 amountLYTOut) {
        if (rawToken == baseToken) {
            IERC20(rawToken).transferFrom(msg.sender, LYT, amountRawTokenIn);
        } else {
            IERC20(rawToken).transferFrom(msg.sender, _getFirstPair(path), amountRawTokenIn);
            _swapExactIn(path, amountRawTokenIn, LYT);
        }

        amountLYTOut = ILiquidYieldToken(LYT).depositBaseToken(
            recipient,
            baseToken,
            minAmountLYTOut
        );
    }

    function swapExactLYTToRawToken(
        address LYT,
        uint256 amountLYTIn,
        address baseToken,
        address rawToken,
        uint256 minAmountRawTokenOut,
        address recipient,
        address[] calldata path
    ) public returns (uint256 amountRawTokenOut) {
        IERC20(LYT).safeTransferFrom(msg.sender, LYT, amountLYTIn);

        if (rawToken == baseToken) {
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
