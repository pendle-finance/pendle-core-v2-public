// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "./base/PendleRouterMarketBase.sol";
import "../../libraries/helpers/MarketHelper.sol";
import "../../SuperComposableYield/implementations/SCYUtils.sol";

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
     - callback will call YT's redeemYO, which will redeem the outcome SCY to this router, then
        all SCY owed to the market will be paid, the rest is transferred to the recipient
     */
    function swapExactYtForSCY(
        address recipient,
        address market,
        uint256 exactYtIn,
        uint256 minSCYOut
    ) external returns (uint256 netSCYOut) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        // takes out the same amount of OT as exactYtIn, to pair together
        uint256 exactOtOut = exactYtIn;

        uint256 preBalanceSCY = _market.SCY.balanceOf(recipient);

        _market.YT.transferFrom(msg.sender, address(_market.YT), exactYtIn);

        // because of SCY / YO conversion, the number may not be 100% accurate. TODO: find a better way
        IPMarket(market).swapSCYForExactOt(
            recipient,
            exactOtOut,
            type(uint256).max,
            abi.encode(msg.sender, recipient)
        );

        netSCYOut = _market.SCY.balanceOf(recipient) - preBalanceSCY;
        require(netSCYOut >= minSCYOut, "INSUFFICIENT_SCY_OUT");
    }

    /**
     * @dev inner working of this function:
     - market.swap is called, which will transfer SCY directly to the YT contract, and callback is invoked
     - callback will pull more SCY if necessary, do call YT's mintYO, which will mint OT to the market & YT to the recipient
     */
    function swapSCYForExactYt(
        address recipient,
        address market,
        uint256 exactYtOut,
        uint256 maxSCYIn
    ) external returns (uint256 netSCYIn) {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 exactOtIn = exactYtOut;
        uint256 preBalanceSCY = _market.SCY.balanceOf(recipient);

        IPMarket(market).swapExactOtForSCY(
            recipient,
            exactOtIn,
            1,
            abi.encode(msg.sender, recipient)
        );

        netSCYIn = preBalanceSCY - _market.SCY.balanceOf(recipient);

        require(netSCYIn <= maxSCYIn, "exceed out limit");
    }

    function swapCallback(
        int256 otToAccount,
        int256 scyToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        // make sure payer, recipient same as when encode
        (address payer, address recipient) = abi.decode(data, (address, address));
        if (scyToAccount > 0) {
            _swapSCYForExactYt_callback(msg.sender, otToAccount, scyToAccount, payer, recipient);
        } else {
            _swapExactYtForSCY_callback(msg.sender, scyToAccount, recipient);
        }
    }

    function _swapSCYForExactYt_callback(
        address market,
        int256 otToAccount,
        int256 scyToAccount,
        address payer,
        address recipient
    ) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 otOwed = otToAccount.neg().Uint();
        uint256 scyReceived = scyToAccount.Uint();

        // otOwed = totalAsset
        uint256 scyNeedTotal = SCYUtils.assetToSCY(_market.SCY.scyIndexCurrent(), otOwed);

        uint256 netSCYToPull = scyNeedTotal.subMax0(scyReceived);
        _market.SCY.transferFrom(payer, address(_market.YT), netSCYToPull);

        _market.YT.mintYO(market, recipient);
    }

    /**
    @dev receive OT -> pair with YT to redeem SCY -> payback SCY
    */
    function _swapExactYtForSCY_callback(
        address market,
        int256 scyToAccount,
        address recipient
    ) internal {
        MarketHelper.MarketStruct memory _market = MarketHelper.readMarketInfo(market);

        uint256 scyOwed = scyToAccount.neg().Uint();

        uint256 netSCYReceived = _market.YT.redeemYO(address(this));

        _market.SCY.transfer(market, scyOwed);
        _market.SCY.transfer(recipient, netSCYReceived - scyOwed);
    }
}
