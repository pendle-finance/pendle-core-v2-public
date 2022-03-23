// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouterForge.sol";
import "./PendleRouterCore.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";

contract PendleRouterRawTokenOT is PendleRouterForge, PendleRouterMarketBase {
    constructor(
        address _joeRouter,
        address _joeFactory,
        address _marketFactory
    ) PendleRouterForge(_joeRouter, _joeFactory) PendleRouterMarketBase(_marketFactory) {}

    function swapExactRawTokenForOT(
        address rawToken,
        uint256 amountRawTokenIn,
        address baseToken,
        address recipient,
        address[] calldata path,
        address market,
        uint256 minAmountOTOut
    ) external {
        address LYT = IPMarket(market).LYT();
        swapExactRawTokenForLYT(rawToken, amountRawTokenIn, baseToken, LYT, 1, market, path);

        int256 otToAccount = netOtOut.toInt();
        int256 lytToAccount = IPMarket(market).swap(
            recipient,
            otToAccount,
            abi.encode(msg.sender)
        );
        netLytIn = lytToAccount.neg().toUint();
        require(netLytIn <= maxLytIn, "LYT_IN_LIMIT_EXCEEDED");

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

    // function swapExactOTForBaseToken(
    //     address market,
    //     uint256 amountOTIn,
    //     address baseToken,
    //     uint256 minAmountBaseTokenOut,
    //     address recipient,
    //     bytes calldata data
    // ) external returns (uint256 amountBaseTokenOut) {
    //     address LYT = IPMarket(market).LYT();

    //     uint256 amountLYTReceived = swapExactOTForLYT(address(this), market, amountOTIn, 0);
    //     amountBaseTokenOut = swapExactLYTForBaseToken(
    //         LYT,
    //         amountLYTReceived,
    //         baseToken,
    //         minAmountBaseTokenOut,
    //         recipient,
    //         data
    //     );
    // }
}
