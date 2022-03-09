// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleRouterCore.sol";
import "../../interfaces/IPOwnershipToken.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPLiquidYieldToken.sol";
import "../../libraries/helpers/MarketHelper.sol";

contract PendleRouter03 is PendleRouterBase {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    struct DataLYTForExactYT {
        address recipient;
        address orgSender;
        uint256 maxAmountLYTIn;
    }

    struct DataExactYTForLYT {
        address recipient;
        address orgSender;
        uint256 minAmountLYTOut;
    }

    enum Mode {
        LYTtoYT,
        YTtoLYT
    }

    constructor(address _marketFactory) PendleRouterBase(_marketFactory) {}

    function callback(
        int256 amountOTIn,
        int256 amountLYTIn,
        bytes calldata data
    ) external override onlycallback(msg.sender) returns (bytes memory res) {
        (Mode mode, ) = abi.decode(data, (Mode, bytes));
        if (mode == Mode.LYTtoYT) {
            res = _swapLYTForExactYT_callback(msg.sender, amountOTIn, amountLYTIn, data);
        } else if (mode == Mode.YTtoLYT) {
            res = _swapExactYTForLYT_callback(msg.sender, amountOTIn, amountLYTIn, data);
        }
    }

    function swapLYTForExactYT(
        address market,
        uint256 maxAmountLYTIn,
        uint256 amountYTOut,
        address recipient
    ) external returns (uint256 amountLYTIn) {
        int256 amountOTToAccount = amountYTOut.toInt();
        (, bytes memory res) = IPMarket(market).swap(
            address(this),
            amountOTToAccount,
            abi.encode(
                Mode.LYTtoYT,
                DataLYTForExactYT({
                    recipient: recipient,
                    orgSender: msg.sender,
                    maxAmountLYTIn: maxAmountLYTIn
                })
            )
        );
        amountLYTIn = abi.decode(res, (uint256));
    }

    function swapExactYTForLYT(
        address market,
        uint256 amountYTIn,
        uint256 minAmountLYTOut,
        address recipient
    ) external returns (uint256 amountLYTOut) {
        // amountOTOut = amountYTIn
        int256 amountOTToAccount = amountYTIn.toInt().neg();
        (, bytes memory res) = IPMarket(market).swap(
            address(this),
            amountOTToAccount,
            abi.encode(
                Mode.YTtoLYT,
                DataExactYTForLYT({
                    recipient: recipient,
                    orgSender: msg.sender,
                    minAmountLYTOut: minAmountLYTOut
                })
            )
        );
        amountLYTOut = abi.decode(res, (uint256));
    }

    function _swapLYTForExactYT_callback(
        address marketAddr,
        int256 amountOTIn_raw,
        int256 amountLYTIn_raw,
        bytes calldata data_raw
    ) internal returns (bytes memory res) {
        MarketHelper.MarketStruct memory market = MarketHelper.readMarketInfo(marketAddr);

        uint256 amountOTIn = amountOTIn_raw.toUint();
        uint256 amountLYTOut = amountLYTIn_raw.neg().toUint();
        DataLYTForExactYT memory data = abi.decode(data_raw, (DataLYTForExactYT));

        uint256 totalAmountLYTNeed = amountOTIn.divDown(market.LYT.exchangeRateCurrent());
        uint256 amountLYTToPull = totalAmountLYTNeed.subMax0(amountLYTOut);
        require(amountLYTToPull <= data.maxAmountLYTIn, "INSUFFICIENT_LYT_IN");
        market.LYT.transferFrom(data.orgSender, address(this), amountLYTToPull);

        // tokenize LYT to OT + YT
        market.LYT.transfer(address(market.YT), totalAmountLYTNeed);
        uint256 amountOTRecieved = market.YT.tokenizeYield(address(this));

        // payback OT to the market
        market.OT.transfer(marketAddr, amountOTRecieved);
        // transfer YT out to user
        market.YT.transfer(data.recipient, amountOTRecieved);

        res = abi.encode(amountLYTToPull);
    }

    function _swapExactYTForLYT_callback(
        address marketAddr,
        int256,
        int256 amountLYTIn_raw,
        bytes calldata data_raw
    ) internal returns (bytes memory res) {
        MarketHelper.MarketStruct memory market = MarketHelper.readMarketInfo(marketAddr);

        uint256 amountLYTIn = amountLYTIn_raw.toUint();
        DataExactYTForLYT memory data = abi.decode(data_raw, (DataExactYTForLYT));

        market.YT.transferFrom(
            data.orgSender,
            address(market.YT),
            market.YT.balanceOf(address(this))
        );
        market.OT.transfer(address(market.YT), market.OT.balanceOf(address(this)));

        uint256 amountLYTReceived = market.YT.redeemUnderlying(address(this));
        uint256 amountLYTOutToUser = amountLYTReceived - amountLYTIn;
        require(amountLYTOutToUser >= data.minAmountLYTOut, "INSUFFICIENT_LYT_OUT");

        market.LYT.transfer(marketAddr, amountLYTIn);
        market.LYT.transfer(data.recipient, amountLYTOutToUser);

        res = abi.encode(amountLYTOutToUser);
    }
}
