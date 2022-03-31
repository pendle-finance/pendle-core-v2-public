// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../interfaces/IPMarketSwapCallback.sol";
import "../base/PendleRouterMarketBase.sol";

contract PendleRouterOT is PendleRouterMarketBase {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using MarketMathLib for MarketParameters;

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
        uint256 otDesired,
        uint256 minLpOut,
        bool doPull
    )
        external
        returns (
            uint256 netLpOut,
            uint256 lytUsed,
            uint256 otUsed
        )
    {
        MarketParameters memory state = IPMarket(market).readState();
        (, netLpOut, lytUsed, otUsed) = state.addLiquidity(lytDesired, otDesired);

        require(netLpOut >= minLpOut, "insufficient lp out");

        if (doPull) {
            address LYT = IPMarket(market).LYT();
            address OT = IPMarket(market).OT();

            IERC20(LYT).transferFrom(msg.sender, market, lytUsed);
            IERC20(OT).transferFrom(msg.sender, market, otUsed);
        }

        IPMarket(market).addLiquidity(recipient, otDesired, lytDesired, abi.encode());
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
        uint256 lytOutMin,
        uint256 otOutMin,
        bool doPull
    ) external returns (uint256 netLytOut, uint256 netOtOut) {
        MarketParameters memory state = IPMarket(market).readState();

        (netLytOut, netOtOut) = state.removeLiquidity(lpToRemove);
        require(netLytOut >= lytOutMin, "insufficient lyt out");
        require(netOtOut >= otOutMin, "insufficient ot out");

        if (doPull) {
            IPMarket(market).transferFrom(msg.sender, market, lpToRemove);
        }

        IPMarket(market).removeLiquidity(recipient, lpToRemove, abi.encode());
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
        uint256 minLytOut,
        bool doPull
    ) public returns (uint256 netLytOut) {
        if (doPull) {
            address OT = IPMarket(market).OT();
            IERC20(OT).transferFrom(msg.sender, market, exactOtIn);
        }

        (netLytOut, ) = IPMarket(market).swapExactOtForLyt(
            recipient,
            exactOtIn,
            minLytOut,
            abi.encode()
        );

        require(netLytOut >= minLytOut, "insufficient lyt out");
    }

    function swapOtForExactLyt(
        address recipient,
        address market,
        uint256 maxOtIn,
        uint256 exactLytOut,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax,
        bool doPull
    ) public returns (uint256 netOtIn) {
        MarketParameters memory state = IPMarket(market).readState();

        netOtIn = state.approxSwapOtForExactLyt(
            exactLytOut,
            state.getTimeToExpiry(),
            netOtInGuessMin,
            netOtInGuessMax
        );

        require(netOtIn <= maxOtIn, "ot in exceed limit");

        if (doPull) {
            address OT = IPMarket(market).OT();
            IERC20(OT).transferFrom(msg.sender, market, netOtIn);
        }

        IPMarket(market).swapExactOtForLyt(recipient, netOtIn, exactLytOut, abi.encode());
    }

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
        uint256 maxLytIn,
        bool doPull
    ) public returns (uint256 netLytIn) {
        MarketParameters memory state = IPMarket(market).readState();

        (netLytIn, ) = state.calcLytForExactOt(exactOtOut, state.getTimeToExpiry());
        require(netLytIn <= maxLytIn, "exceed limit lyt in");

        if (doPull) {
            address LYT = IPMarket(market).LYT();
            IERC20(LYT).transferFrom(msg.sender, market, netLytIn);
        }

        IPMarket(market).swapLytForExactOt(
            recipient,
            exactOtOut,
            maxLytIn,
            abi.encode(msg.sender)
        );
    }

    function swapExactLytForOt(
        address recipient,
        address market,
        uint256 exactLytIn,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax,
        bool doPull
    ) public returns (uint256 netOtOut) {
        MarketParameters memory state = IPMarket(market).readState();

        if (netOtOutGuessMax == type(uint256).max) {
            netOtOutGuessMax = state.totalOt.Uint();
        }

        netOtOut = state.approxSwapExactLytForOt(
            exactLytIn,
            state.getTimeToExpiry(),
            netOtOutGuessMin,
            netOtOutGuessMax
        );

        require(netOtOut >= minOtOut, "insufficient out");

        if (doPull) {
            address LYT = IPMarket(market).LYT();
            IERC20(LYT).transferFrom(msg.sender, market, exactLytIn);
        }

        IPMarket(market).swapLytForExactOt(
            recipient,
            netOtOut,
            exactLytIn,
            abi.encode(msg.sender)
        );
    }
}
