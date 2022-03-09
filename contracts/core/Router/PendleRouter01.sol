// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IPLiquidYieldToken.sol";

contract PendleRouter01 {
    using SafeERC20 for IERC20;

    function swapExactBaseTokenForLYT(
        address baseToken,
        uint256 amountBaseTokenIn,
        address LYT,
        uint256 minAmountLYTOut,
        address recipient,
        bytes calldata data
    ) public returns (uint256 amountLYTOut) {
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), amountBaseTokenIn);
        amountLYTOut = IPLiquidYieldToken(LYT).mintFromBaseToken(
            recipient,
            baseToken,
            amountBaseTokenIn,
            minAmountLYTOut,
            data
        );
    }

    function swapExactLYTForBaseToken(
        address LYT,
        uint256 amountLYTIn,
        address baseToken,
        uint256 minAmountBaseTokenOut,
        address recipient,
        bytes calldata data
    ) public returns (uint256 amountBaseTokenOut) {
        IERC20(LYT).safeTransferFrom(msg.sender, address(this), amountLYTIn);
        amountBaseTokenOut = IPLiquidYieldToken(LYT).burnToBaseToken(
            recipient,
            baseToken,
            amountLYTIn,
            minAmountBaseTokenOut,
            data
        );
    }
}
