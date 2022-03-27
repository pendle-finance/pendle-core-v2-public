// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../base/PendleRouterMarketBase.sol";

contract PendleRouterOT is
    PendleRouterMarketBase,
    IPMarketAddRemoveCallback,
    IPMarketSwapCallback
{
    using FixedPoint for uint256;
    using FixedPoint for int256;

    constructor(address _marketFactory)
        PendleRouterMarketBase(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    function addLiquidity(
        address recipient,
        address market,
        uint256 lytDesired,
        uint256 otDesired
    )
        external
        returns (
            uint256 lpToAccount,
            uint256 lytUsed,
            uint256 otUsed
        )
    {
        (lpToAccount, lytUsed, otUsed) = IPMarket(market).addLiquidity(
            recipient,
            otDesired,
            lytDesired,
            abi.encode(msg.sender)
        );
    }

    function removeLiquidity(
        address recipient,
        address market,
        uint256 lpToRemove
    ) external returns (uint256 otToAccount, uint256 lytToAccount) {
        (lytToAccount, otToAccount) = IPMarket(market).removeLiquidity(
            recipient,
            lpToRemove,
            abi.encode(msg.sender)
        );
    }

    function swapExactOtForLyt(
        address recipient,
        address market,
        uint256 exactOtIn,
        uint256 minLytOut
    ) public returns (uint256 netLytOut) {
        int256 otToAccount = exactOtIn.toInt().neg();
        int256 lytToAccount = IPMarket(market).swap(
            recipient,
            otToAccount,
            abi.encode(msg.sender)
        );
        netLytOut = lytToAccount.toUint();
        require(netLytOut >= minLytOut, "INSUFFICIENT_LYT_OUT");
    }

    function swapLytForExactOt(
        address recipient,
        address market,
        uint256 exactOtOut,
        uint256 maxLytIn
    ) public returns (uint256 netLytIn) {
        int256 otToAccount = exactOtOut.toInt();
        int256 lytToAccount = IPMarket(market).swap(
            recipient,
            otToAccount,
            abi.encode(msg.sender)
        );
        netLytIn = lytToAccount.neg().toUint();
        require(netLytIn <= maxLytIn, "LYT_IN_LIMIT_EXCEEDED");
    }

    function addLiquidityCallback(
        uint256,
        uint256 lytOwed,
        uint256 otOwed,
        bytes calldata data
    ) external onlyPendleMarket(msg.sender) {
        IPMarket market = IPMarket(msg.sender);
        address payer = abi.decode(data, (address));
        IERC20(market.OT()).transferFrom(payer, msg.sender, otOwed);
        IERC20(market.LYT()).transferFrom(payer, msg.sender, lytOwed);
    }

    function removeLiquidityCallback(
        uint256 lpToRemove,
        uint256,
        uint256,
        bytes calldata data
    ) external onlyPendleMarket(msg.sender) {
        IPMarket market = IPMarket(msg.sender);
        address payer = abi.decode(data, (address));
        market.transferFrom(payer, msg.sender, lpToRemove);
    }

    function swapCallback(
        int256 otToAccount,
        int256 lytToAccount,
        bytes calldata data
    ) external override onlyPendleMarket(msg.sender) {
        IPMarket market = IPMarket(msg.sender);
        address payer = abi.decode(data, (address));
        if (otToAccount < 0)
            IERC20(market.OT()).transferFrom(payer, msg.sender, otToAccount.neg().toUint());
        if (lytToAccount < 0)
            IERC20(market.LYT()).transferFrom(payer, msg.sender, lytToAccount.neg().toUint());
    }
}
