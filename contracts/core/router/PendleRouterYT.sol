// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../base/PendleRouterMarketBase.sol";
import "../../libraries/helpers/MarketHelper.sol";

contract PendleRouterYT is PendleRouterMarketBase, IPMarketSwapCallback {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(address _marketFactory) PendleRouterMarketBase(_marketFactory) {}

    function swapExactYTForLYT(
        address recipient,
        address market,
        uint256 netYtIn,
        uint256 minLytOut
    ) external returns (uint256 netLytOut) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        // takes out the same amount of OT as netYtIn, to pair together
        int256 otToAccount = netYtIn.toInt();

        uint256 preBalanceLyt = _market.LYT.balanceOf(recipient);

        _market.YT.transferFrom(msg.sender, address(_market.YT), netYtIn);

        // because of LYT / YO conversion, the number may not be 100% accurate. TODO: find a better way
        IPMarket(market).swap(address(_market.YT), otToAccount, abi.encode(msg.sender, recipient));

        netLytOut = _market.LYT.balanceOf(recipient) - preBalanceLyt;
        require(netLytOut >= minLytOut, "INSUFFICIENT_LYT_OUT");
    }

    function swapLYTForExactYT(
        address recipient,
        address market,
        uint256 netYtOut,
        uint256 maxLytIn
    ) external returns (uint256 netLytIn) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        int256 otToAccount = netYtOut.toInt().neg();
        uint256 preBalanceLyt = _market.LYT.balanceOf(recipient);

        IPMarket(market).swap(address(_market.YT), otToAccount, abi.encode(msg.sender, recipient));

        netLytIn = preBalanceLyt - _market.LYT.balanceOf(recipient);

        require(netLytIn <= maxLytIn, "exceed out limit");
    }

    function swapCallback(
        int256 otToAccount,
        int256 lytToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        // make sure payer, recipient same as when encode
        (address payer, address recipient) = abi.decode(data, (address, address));
        if (lytToAccount > 0) {
            _swapExactYTForLYT_callback(msg.sender, lytToAccount, recipient);
        } else {
            _swapLYTForExactYT_callback(msg.sender, otToAccount, lytToAccount, payer, recipient);
        }
    }

    function _swapLYTForExactYT_callback(
        address market,
        int256 otToAccount,
        int256 lytToAccount,
        address payer,
        address recipient
    ) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 amountOtOwed = otToAccount.neg().toUint();
        uint256 amountLytReceived = lytToAccount.toUint();

        uint256 amountLytNeedTotal = amountOtOwed.divDown(_market.LYT.lytIndexCurrent());

        uint256 amountLytToPull = amountLytNeedTotal.subMax0(amountLytReceived);
        _market.LYT.transferFrom(payer, address(_market.YT), amountLytToPull);

        uint256 amountYOOut = _market.YT.mintYO(address(this));

        _market.YT.transfer(recipient, amountYOOut);

        _market.OT.transfer(market, amountYOOut);
    }

    /**
    @dev receive OT -> pair with YT to redeem LYT -> payback LYT
    */
    function _swapExactYTForLYT_callback(
        address market,
        int256 lytToAccount,
        address recipient
    ) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 amountLytOwed = lytToAccount.neg().toUint();

        _market.YT.redeemYO(recipient);

        // this looks off tbh, why force recipient to approve?
        _market.LYT.transferFrom(recipient, market, amountLytOwed);
    }
}
