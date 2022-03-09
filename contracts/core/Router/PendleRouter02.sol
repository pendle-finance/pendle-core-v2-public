// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouter01.sol";
import "./PendleRouterCore.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";

contract PendleRouter02 is PendleRouter01, PendleRouterCore {
    constructor(address _marketFactory) PendleRouterCore(_marketFactory) {}

    function swapBaseTokenForExactOT(
        address market,
        address baseToken,
        uint256 amountBaseTokenIn,
        uint256 amountOTOut,
        address recipient,
        bytes calldata data
    ) external {
        address LYT = IPMarket(market).LYT();

        uint256 amountLYTReceived = swapExactBaseTokenForLYT(
            baseToken,
            amountBaseTokenIn,
            LYT,
            0, // can have a minLYTOut here to make it fail earlier
            address(this),
            data
        );

        uint256 amountLYTIn = swapLYTForExactOT(recipient, market, amountOTOut, amountLYTReceived);
        assert(amountLYTIn == amountLYTReceived);
    }

    function swapExactOTForBaseToken(
        address market,
        uint256 amountOTIn,
        address baseToken,
        uint256 minAmountBaseTokenOut,
        address recipient,
        bytes calldata data
    ) external returns (uint256 amountBaseTokenOut) {
        address LYT = IPMarket(market).LYT();

        uint256 amountLYTReceived = swapExactOTForLYT(address(this), market, amountOTIn, 0);
        amountBaseTokenOut = swapExactLYTForBaseToken(
            LYT,
            amountLYTReceived,
            baseToken,
            minAmountBaseTokenOut,
            recipient,
            data
        );
    }
}
