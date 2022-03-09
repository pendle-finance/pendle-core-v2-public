// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../base/PendleRouterBase.sol";

contract PendleRouterCore is PendleRouterBase {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using MarketMathLib for MarketParameters;

    constructor(address _marketFactory) PendleRouterBase(_marketFactory) {}

    function callback(
        int256 amountOTIn,
        int256 amountLYTIn,
        bytes calldata cbData
    ) external override onlycallback(msg.sender) returns (bytes memory cbRes) {
        IPMarket market = IPMarket(msg.sender);
        address payer = abi.decode(cbData, (address));
        if (amountOTIn > 0) {
            IERC20(market.OT()).transferFrom(payer, msg.sender, amountOTIn.toUint());
        } else {
            IERC20(market.LYT()).transferFrom(payer, msg.sender, amountLYTIn.toUint());
        }
        // encode nothing
        cbRes = abi.encode();
    }

    function addLiquidity(
        address recipient,
        address market,
        uint256 amountOTDesired,
        uint256 amountLYTDesired
    )
        external
        returns (
            uint256 lpOut,
            uint256 amountOTUsed,
            uint256 amountLYTUsed
        )
    {
        MarketParameters memory marketState = IPMarket(market).readState();
        (, lpOut, amountLYTUsed, amountOTUsed) = marketState.addLiquidity(
            amountLYTDesired,
            amountOTDesired
        );
        IPMarket _market = IPMarket(msg.sender);
        IERC20(_market.OT()).transferFrom(msg.sender, market, amountOTUsed);
        IERC20(_market.LYT()).transferFrom(msg.sender, market, amountLYTUsed);
        _market.addLiquidity(recipient);
    }

    function removeLiquidity(
        address recipient,
        address market,
        uint256 amountLpToRemove
    ) external returns (uint256 amountOTOut, uint256 amountLYTOut) {
        IPMarket _market = IPMarket(msg.sender);
        _market.transferFrom(msg.sender, market, amountLpToRemove);
        (amountLYTOut, amountOTOut) = _market.removeLiquidity(recipient);
    }

    function swapExactOTForLYT(
        address recipient,
        address market,
        uint256 amountOTIn,
        uint256 minAmountLYTOut
    ) public returns (uint256 amountLYTOut) {
        int256 amountOTToAccount = amountOTIn.toInt().neg();
        (int256 amountLYTToAccount, ) = IPMarket(market).swap(
            recipient,
            amountOTToAccount,
            abi.encode(msg.sender)
        );
        amountLYTOut = amountLYTToAccount.toUint();
        require(amountLYTOut >= minAmountLYTOut, "INSUFFICIENT_LYT_OUT");
    }

    function swapLYTForExactOT(
        address recipient,
        address market,
        uint256 amountOTOut,
        uint256 maxAmountLYTIn
    ) public returns (uint256 amountLYTIn) {
        int256 amountOTToAccount = amountOTOut.toInt();
        (int256 amountLYTToAccount, ) = IPMarket(market).swap(
            recipient,
            amountOTToAccount,
            abi.encode(msg.sender)
        );
        amountLYTIn = amountLYTToAccount.neg().toUint();
        require(amountLYTIn <= maxAmountLYTIn, "LYT_IN_LIMIT_EXCEEDED");
    }
}
