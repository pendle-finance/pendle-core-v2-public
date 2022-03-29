// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../base/PendleRouterMarketBase.sol";
import "../../libraries/helpers/MarketHelper.sol";
import "../../LiquidYieldToken/implementations/LYTUtils.sol";

contract PendleRouterYT is PendleRouterMarketBase, IPMarketSwapCallback {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(address _marketFactory)
        PendleRouterMarketBase(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    /**
    * @dev inner working of this function:
     - YT is transferred to the YT contract
     - market.swap is called, which will transfer OT directly to the YT contract, and callback is invoked
     - callback will call YT's redeemYO, which will redeem the outcome LYT to this router, then
        all LYT owed to the market will be paid, the rest is transferred to the recipient
     */
    function swapExactYtForLyt(
        address recipient,
        address market,
        uint256 exactYtIn,
        uint256 minLytOut
    ) external returns (uint256 netLytOut) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        // takes out the same amount of OT as exactYtIn, to pair together
        int256 otToAccount = exactYtIn.Int();

        uint256 preBalanceLyt = _market.LYT.balanceOf(recipient);

        _market.YT.transferFrom(msg.sender, address(_market.YT), exactYtIn);

        // because of LYT / YO conversion, the number may not be 100% accurate. TODO: find a better way
        IPMarket(market).swap(address(_market.YT), otToAccount, abi.encode(msg.sender, recipient));

        netLytOut = _market.LYT.balanceOf(recipient) - preBalanceLyt;
        require(netLytOut >= minLytOut, "INSUFFICIENT_LYT_OUT");
    }

    /**
     * @dev inner working of this function:
     - market.swap is called, which will transfer LYT directly to the YT contract, and callback is invoked
     - callback will pull more LYT if necessary, do call YT's mintYO, which will mint OT to the market & YT to the recipient
     */
    function swapLytForExactYt(
        address recipient,
        address market,
        uint256 exactYtOut,
        uint256 maxLytIn
    ) external returns (uint256 netLytIn) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        int256 otToAccount = exactYtOut.neg();
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
            _swapLytForExactYt_callback(msg.sender, otToAccount, lytToAccount, payer, recipient);
        } else {
            _swapExactYtForLyt_callback(msg.sender, lytToAccount, recipient);
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

        uint256 otOwed = otToAccount.neg().Uint();
        uint256 lytReceived = lytToAccount.Uint();

        // otOwed = totalAsset
        uint256 lytNeedTotal = LYTUtils.assetToLyt(_market.LYT.lytIndexCurrent(), otOwed);

        uint256 netLytToPull = lytNeedTotal.subMax0(lytReceived);
        _market.LYT.transferFrom(payer, address(_market.YT), netLytToPull);

        _market.YT.mintYO(market, recipient);
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

        uint256 lytOwed = lytToAccount.neg().Uint();

        uint256 netLytReceived = _market.YT.redeemYO(address(this));

        _market.LYT.transfer(market, lytOwed);
        _market.LYT.transfer(recipient, netLytReceived - lytOwed);
    }
}
