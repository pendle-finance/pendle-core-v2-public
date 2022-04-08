// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../../interfaces/IPMarketSwapCallback.sol";
import "../../../interfaces/IPRouterOT.sol";
import "../base/PendleRouterMarketBaseUpg.sol";

abstract contract PendleRouterOTUpg is PendleRouterMarketBaseUpg, IPRouterOT {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using MarketMathLib for MarketParameters;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _marketFactory)
        PendleRouterMarketBaseUpg(_marketFactory)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    function addLiquidity(
        address recipient,
        address market,
        uint256 scyDesired,
        uint256 otDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return _addLiquidity(recipient, market, scyDesired, otDesired, minLpOut, true);
    }

    function removeLiquidity(
        address recipient,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 otOutMin
    ) external returns (uint256, uint256) {
        return _removeLiquidity(recipient, market, lpToRemove, scyOutMin, otOutMin, true);
    }

    function swapExactOtForSCY(
        address recipient,
        address market,
        uint256 exactOtIn,
        uint256 minSCYOut
    ) external returns (uint256) {
        return _swapExactOtForSCY(recipient, market, exactOtIn, minSCYOut, true);
    }

    function swapOtForExactSCY(
        address recipient,
        address market,
        uint256 maxOtIn,
        uint256 exactSCYOut,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax
    ) external returns (uint256) {
        return
            _swapOtForExactSCY(
                recipient,
                market,
                maxOtIn,
                exactSCYOut,
                netOtInGuessMin,
                netOtInGuessMax,
                true
            );
    }

    function swapSCYForExactOt(
        address recipient,
        address market,
        uint256 exactOtOut,
        uint256 maxSCYIn
    ) external returns (uint256) {
        return _swapSCYForExactOt(recipient, market, exactOtOut, maxSCYIn, true);
    }

    function swapExactSCYForOt(
        address recipient,
        address market,
        uint256 exactSCYIn,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax
    ) external returns (uint256) {
        return
            _swapExactSCYForOt(
                recipient,
                market,
                exactSCYIn,
                minOtOut,
                netOtOutGuessMin,
                netOtOutGuessMax,
                true
            );
    }

    /**
     * @notice addLiquidity to the market, using both SCY & OT, the recipient will receive LP before
     msg.sender is required to pay SCY & OT
     * @dev inner working of this function:
     - market.addLiquidity is called
     - LP is minted to the recipient, and this router's addLiquidityCallback is invoked
     - the router will transfer the necessary scy & ot from msg.sender to the market, and finish the callback
     */
    function _addLiquidity(
        address recipient,
        address market,
        uint256 scyDesired,
        uint256 otDesired,
        uint256 minLpOut,
        bool doPull
    )
        internal
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 otUsed
        )
    {
        MarketParameters memory state = IPMarket(market).readState();
        (, netLpOut, scyUsed, otUsed) = state.addLiquidity(scyDesired, otDesired);

        require(netLpOut >= minLpOut, "insufficient lp out");

        if (doPull) {
            address SCY = IPMarket(market).SCY();
            address OT = IPMarket(market).OT();

            IERC20(SCY).transferFrom(msg.sender, market, scyUsed);
            IERC20(OT).transferFrom(msg.sender, market, otUsed);
        }

        IPMarket(market).addLiquidity(recipient, otDesired, scyDesired, abi.encode());
    }

    /**
     * @notice removeLiquidity from the market to receive both SCY & OT. The recipient will receive
     SCY & OT before msg.sender is required to transfer in the necessary LP
     * @dev inner working of this function:
     - market.removeLiquidity is called
     - SCY & OT is transferred to the recipient, and the router's callback is invoked
     - the router will transfer the necessary LP from msg.sender to the market, and finish the callback
     */
    function _removeLiquidity(
        address recipient,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 otOutMin,
        bool doPull
    ) internal returns (uint256 netSCYOut, uint256 netOtOut) {
        MarketParameters memory state = IPMarket(market).readState();

        (netSCYOut, netOtOut) = state.removeLiquidity(lpToRemove);
        require(netSCYOut >= scyOutMin, "insufficient scy out");
        require(netOtOut >= otOutMin, "insufficient ot out");

        if (doPull) {
            IPMarket(market).transferFrom(msg.sender, market, lpToRemove);
        }

        IPMarket(market).removeLiquidity(recipient, lpToRemove, abi.encode());
    }

    /**
     * @notice swap exact OT for SCY, with recipient receiving SCY before msg.sender is required to
     transfer the owed OT
     * @dev inner working of this function:
     - market.swap is called
     - SCY is transferred to the recipient, and the router's callback is invoked
     - the router will transfer the necessary OT from msg.sender to the market, and finish the callback
     */
    function _swapExactOtForSCY(
        address recipient,
        address market,
        uint256 exactOtIn,
        uint256 minSCYOut,
        bool doPull
    ) internal returns (uint256 netSCYOut) {
        if (doPull) {
            address OT = IPMarket(market).OT();
            IERC20(OT).transferFrom(msg.sender, market, exactOtIn);
        }

        (netSCYOut, ) = IPMarket(market).swapExactOtForSCY(
            recipient,
            exactOtIn,
            minSCYOut,
            abi.encode()
        );

        require(netSCYOut >= minSCYOut, "insufficient scy out");
    }

    function _swapOtForExactSCY(
        address recipient,
        address market,
        uint256 maxOtIn,
        uint256 exactSCYOut,
        uint256 netOtInGuessMin,
        uint256 netOtInGuessMax,
        bool doPull
    ) internal returns (uint256 netOtIn) {
        MarketParameters memory state = IPMarket(market).readState();

        netOtIn = state.approxSwapOtForExactSCY(
            exactSCYOut,
            state.getTimeToExpiry(),
            netOtInGuessMin,
            netOtInGuessMax
        );

        require(netOtIn <= maxOtIn, "ot in exceed limit");

        if (doPull) {
            address OT = IPMarket(market).OT();
            IERC20(OT).transferFrom(msg.sender, market, netOtIn);
        }

        IPMarket(market).swapExactOtForSCY(recipient, netOtIn, exactSCYOut, abi.encode());
    }

    /**
     * @notice swap SCY for exact OT, with recipient receiving OT before msg.sender is required to
     transfer the owed SCY
     * @dev inner working of this function:
     - market.swap is called
     - OT is transferred to the recipient, and the router's callback is invoked
     - the router will transfer the necessary SCY from msg.sender to the market, and finish the callback
     */
    function _swapSCYForExactOt(
        address recipient,
        address market,
        uint256 exactOtOut,
        uint256 maxSCYIn,
        bool doPull
    ) internal returns (uint256 netSCYIn) {
        MarketParameters memory state = IPMarket(market).readState();

        (netSCYIn, ) = state.calcSCYForExactOt(exactOtOut, state.getTimeToExpiry());
        require(netSCYIn <= maxSCYIn, "exceed limit scy in");

        if (doPull) {
            address SCY = IPMarket(market).SCY();
            IERC20(SCY).transferFrom(msg.sender, market, netSCYIn);
        }

        IPMarket(market).swapSCYForExactOt(
            recipient,
            exactOtOut,
            maxSCYIn,
            abi.encode(msg.sender)
        );
    }

    function _swapExactSCYForOt(
        address recipient,
        address market,
        uint256 exactSCYIn,
        uint256 minOtOut,
        uint256 netOtOutGuessMin,
        uint256 netOtOutGuessMax,
        bool doPull
    ) internal returns (uint256 netOtOut) {
        MarketParameters memory state = IPMarket(market).readState();

        if (netOtOutGuessMax == type(uint256).max) {
            netOtOutGuessMax = state.totalOt.Uint();
        }

        netOtOut = state.approxSwapExactSCYForOt(
            exactSCYIn,
            state.getTimeToExpiry(),
            netOtOutGuessMin,
            netOtOutGuessMax
        );

        require(netOtOut >= minOtOut, "insufficient out");

        if (doPull) {
            address SCY = IPMarket(market).SCY();
            IERC20(SCY).transferFrom(msg.sender, market, exactSCYIn);
        }

        IPMarket(market).swapSCYForExactOt(
            recipient,
            netOtOut,
            exactSCYIn,
            abi.encode(msg.sender)
        );
    }
}
