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

    constructor(address _marketFactory)
        PendleRouterMarketBase(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    function swapExactYtForLyt(
        address recipient,
        address market,
        uint256 exactYtIn,
        uint256 minLytOut
    ) external returns (uint256 netLytOut) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        // takes out the same amount of OT as exactYtIn, to pair together
        int256 otToAccount = exactYtIn.toInt();

        uint256 preBalanceLyt = _market.LYT.balanceOf(recipient);

        _market.YT.transferFrom(msg.sender, address(_market.YT), exactYtIn);

        // because of LYT / YO conversion, the number may not be 100% accurate. TODO: find a better way
        IPMarket(market).swap(address(_market.YT), otToAccount, abi.encode(msg.sender, recipient));

        netLytOut = _market.LYT.balanceOf(recipient) - preBalanceLyt;
        require(netLytOut >= minLytOut, "INSUFFICIENT_LYT_OUT");
    }

    function swapLytForExactYt(
        address recipient,
        address market,
        uint256 exactYtOut,
        uint256 maxLytIn
    ) external returns (uint256 netLytIn) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        int256 otToAccount = exactYtOut.toInt().neg();
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
            _swapExactYtForLyt_callback(msg.sender, lytToAccount, recipient);
        } else {
            _swapLytForExactYt_callback(msg.sender, otToAccount, lytToAccount, payer, recipient);
        }
    }

    function _swapLytForExactYt_callback(
        address market,
        int256 otToAccount,
        int256 lytToAccount,
        address payer,
        address recipient
    ) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 otOwed = otToAccount.neg().toUint();
        uint256 lytReceived = lytToAccount.toUint();

        uint256 lytOwedTotal = otOwed.divDown(_market.LYT.lytIndexCurrent());

        uint256 netLytToPull = lytOwedTotal.subMax0(lytReceived);
        _market.LYT.transferFrom(payer, address(_market.YT), netLytToPull);

        uint256 netYoOut = _market.YT.mintYO(address(this));

        _market.YT.transfer(recipient, netYoOut);

        _market.OT.transfer(market, netYoOut);
    }

    /**
    @dev receive OT -> pair with YT to redeem LYT -> payback LYT
    */
    function _swapExactYtForLyt_callback(
        address market,
        int256 lytToAccount,
        address recipient
    ) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 lytOwed = lytToAccount.neg().toUint();

        _market.YT.redeemYO(recipient);

        // this looks off tbh, why force recipient to approve?
        _market.LYT.transferFrom(recipient, market, lytOwed);
    }
}
