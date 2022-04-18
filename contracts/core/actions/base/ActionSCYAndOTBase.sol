// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../../interfaces/IPMarketSwapCallback.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "../../../libraries/math/MarketMathAux.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ActionSCYAndOTBase {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using MarketApproxLib for MarketState;
    using SafeERC20 for IERC20;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables

    /**
     * @notice addLiquidity to the market, using both SCY & OT, the receiver will receive LP before
     msg.sender is required to pay SCY & OT
     * @dev inner working of this function:
     - market.addLiquidity is called
     - LP is minted to the receiver, and this router's addLiquidityCallback is invoked
     - the router will transfer the necessary scy & ot from msg.sender to the market, and finish the callback
     */
    function _addLiquidity(
        address receiver,
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
        (ISuperComposableYield SCY, IPOwnershipToken OT, ) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState(false);
        (, netLpOut, scyUsed, otUsed) = state.addLiquidity(
            SCYIndexLib.newIndex(SCY),
            scyDesired,
            otDesired,
            false
        );

        require(netLpOut >= minLpOut, "insufficient lp out");

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, scyUsed);
            IERC20(OT).safeTransferFrom(msg.sender, market, otUsed);
        }

        IPMarket(market).addLiquidity(receiver, otDesired, scyDesired, abi.encode());
    }

    /**
     * @notice removeLiquidity from the market to receive both SCY & OT. The receiver will receive
     SCY & OT before msg.sender is required to transfer in the necessary LP
     * @dev inner working of this function:
     - market.removeLiquidity is called
     - SCY & OT is transferred to the receiver, and the router's callback is invoked
     - the router will transfer the necessary LP from msg.sender to the market, and finish the callback
     */
    function _removeLiquidity(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 otOutMin,
        bool doPull
    ) internal returns (uint256 netScyOut, uint256 netOtOut) {
        MarketState memory state = IPMarket(market).readState(false);

        (netScyOut, netOtOut) = state.removeLiquidity(lpToRemove, false);
        require(netScyOut >= scyOutMin, "insufficient scy out");
        require(netOtOut >= otOutMin, "insufficient ot out");

        if (doPull) {
            IERC20(market).safeTransferFrom(msg.sender, market, lpToRemove);
        }

        IPMarket(market).removeLiquidity(receiver, lpToRemove, abi.encode());
    }

    /**
     * @notice swap exact OT for SCY, with receiver receiving SCY before msg.sender is required to
     transfer the owed OT
     * @dev inner working of this function:
     - market.swap is called
     - SCY is transferred to the receiver, and the router's callback is invoked
     - the router will transfer the necessary OT from msg.sender to the market, and finish the callback
     */
    function _swapExactOtForScy(
        address receiver,
        address market,
        uint256 exactOtIn,
        uint256 minScyOut,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        if (doPull) {
            address OT = IPMarket(market).OT();
            IERC20(OT).safeTransferFrom(msg.sender, market, exactOtIn);
        }

        (netScyOut, ) = IPMarket(market).swapExactOtForScy(
            receiver,
            exactOtIn,
            minScyOut,
            abi.encode()
        );

        require(netScyOut >= minScyOut, "insufficient scy out");
    }

    function _swapOtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netOtIn) {
        MarketState memory state = IPMarket(market).readState(false);
        (ISuperComposableYield SCY, IPOwnershipToken OT, ) = IPMarket(market).readTokens();

        (netOtIn, ) = state.approxSwapOtForExactScy(
            SCYIndexLib.newIndex(SCY),
            exactScyOut,
            block.timestamp,
            approx
        );

        if (doPull) {
            IERC20(OT).safeTransferFrom(msg.sender, market, netOtIn);
        }

        IPMarket(market).swapExactOtForScy(receiver, netOtIn, exactScyOut, abi.encode());
    }

    /**
     * @notice swap SCY for exact OT, with receiver receiving OT before msg.sender is required to
     transfer the owed SCY
     * @dev inner working of this function:
     - market.swap is called
     - OT is transferred to the receiver, and the router's callback is invoked
     - the router will transfer the necessary SCY from msg.sender to the market, and finish the callback
     */
    function _swapScyForExactOt(
        address receiver,
        address market,
        uint256 exactOtOut,
        uint256 maxScyIn,
        bool doPull
    ) internal returns (uint256 netScyIn) {
        MarketState memory state = IPMarket(market).readState(false);
        address SCY = IPMarket(market).SCY();

        (netScyIn, ) = state.swapScyForExactOt(
            SCYIndexLib.newIndex(SCY),
            exactOtOut,
            block.timestamp,
            false
        );
        require(netScyIn <= maxScyIn, "exceed limit scy in");

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, netScyIn);
        }

        IPMarket(market).swapScyForExactOt(receiver, exactOtOut, maxScyIn, abi.encode());
    }

    function _swapExactScyForOt(
        address receiver,
        address market,
        uint256 exactScyIn,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netOtOut) {
        MarketState memory state = IPMarket(market).readState(false);
        address SCY = IPMarket(market).SCY();

        (netOtOut, ) = state.approxSwapExactScyForOt(
            SCYIndexLib.newIndex(SCY),
            exactScyIn,
            block.timestamp,
            approx
        );

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, exactScyIn);
        }

        IPMarket(market).swapScyForExactOt(receiver, netOtOut, exactScyIn, abi.encode());
    }
}
