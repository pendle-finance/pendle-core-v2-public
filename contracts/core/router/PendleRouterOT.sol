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

    /**
     * @notice addLiquidity to the market, using both LYT & OT, the recipient will receive LP before
     msg.sender is required to pay LYT & OT
     * @dev inner working of this function:
     - market.addLiquidity is called
     - LP is minted to the recipient, and this router's addLiquidityCallback is invoked
     - the router will transfer the necessary lyt & ot from msg.sender to the market, and finish the callback
     */
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

    /**
     * @notice removeLiquidity from the market to receive both LYT & OT. The recipient will receive
     LYT & OT before msg.sender is required to transfer in the necessary LP
     * @dev inner working of this function:
     - market.removeLiquidity is called
     - LYT & OT is transferred to the recipient, and the router's callback is invoked
     - the router will transfer the necessary LP from msg.sender to the market, and finish the callback
     */
    function removeLiquidity(
        address recipient,
        address market,
        uint256 lpToRemove,
        uint256 lytToAccountMin,
        uint256 otToAccountMin
    ) external returns (uint256 lytToAccount, uint256 otToAccount) {
        (lytToAccount, otToAccount) = IPMarket(market).removeLiquidity(
            recipient,
            lpToRemove,
            abi.encode(msg.sender)
        );

        require(lytToAccount >= lytToAccountMin, "insufficient lyt out");
        require(otToAccount >= otToAccountMin, "insufficient ot out");
    }

    /**
     * @notice swap exact OT for LYT, with recipient receiving LYT before msg.sender is required to
     transfer the owed OT
     * @dev inner working of this function:
     - market.swap is called
     - LYT is transferred to the recipient, and the router's callback is invoked
     - the router will transfer the necessary OT from msg.sender to the market, and finish the callback
     */
    function swapExactOtForLyt(
        address recipient,
        address market,
        uint256 exactOtIn,
        uint256 minLytOut
    ) public returns (uint256 netLytOut) {
        netLytOut = IPMarket(market).swapExactOtForLyt(
            recipient,
            exactOtIn,
            minLytOut,
            abi.encode(msg.sender)
        );
    }

    // swapOtForExactLyt is also possible, but more gas-consuming

    /**
     * @notice swap LYT for exact OT, with recipient receiving OT before msg.sender is required to
     transfer the owed LYT
     * @dev inner working of this function:
     - market.swap is called
     - OT is transferred to the recipient, and the router's callback is invoked
     - the router will transfer the necessary LYT from msg.sender to the market, and finish the callback
     */
    function swapLytForExactOt(
        address recipient,
        address market,
        uint256 exactOtOut,
        uint256 maxLytIn
    ) public returns (uint256 netLytIn) {
        netLytIn = IPMarket(market).swapLytForExactOt(
            recipient,
            exactOtOut,
            maxLytIn,
            abi.encode(msg.sender)
        );
    }

    // swapExactLytForOt is also possible, but more gas-consuming

    /*///////////////////////////////////////////////////////////////
                CALLBACKS, ONLY ACCESSIBLE BY MARKETS
    //////////////////////////////////////////////////////////////*/

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
            IERC20(market.OT()).transferFrom(payer, msg.sender, otToAccount.abs());
        if (lytToAccount < 0)
            IERC20(market.LYT()).transferFrom(payer, msg.sender, lytToAccount.abs());
    }
}
