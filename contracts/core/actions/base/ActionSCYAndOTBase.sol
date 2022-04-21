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
     * @notice addLiquidity to the market, using both SCY & PT, the receiver will receive LP before
     msg.sender is required to pay SCY & PT
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
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

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
            IERC20(PT).safeTransferFrom(msg.sender, market, otUsed);
        }

        IPMarket(market).addLiquidity(receiver, otDesired, scyDesired, abi.encode()); // ignore return
    }

    /**
     * @notice removeLiquidity from the market to receive both SCY & PT. The receiver will receive
     SCY & PT before msg.sender is required to transfer in the necessary LP
     * @dev inner working of this function:
     - market.removeLiquidity is called
     - SCY & PT is transferred to the receiver, and the router's callback is invoked
     - the router will transfer the necessary LP from msg.sender to the market, and finish the callback
     */
    function _removeLiquidity(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 otOutMin,
        bool doPull
    ) internal returns (uint256 netScyOut, uint256 netPtOut) {
        MarketState memory state = IPMarket(market).readState(false);

        (netScyOut, netPtOut) = state.removeLiquidity(lpToRemove, false);
        require(netScyOut >= scyOutMin, "insufficient scy out");
        require(netPtOut >= otOutMin, "insufficient ot out");

        if (doPull) {
            IERC20(market).safeTransferFrom(msg.sender, market, lpToRemove);
        }

        IPMarket(market).removeLiquidity(receiver, lpToRemove, abi.encode()); // ignore return
    }

    /**
     * @notice swap exact PT for SCY, with receiver receiving SCY before msg.sender is required to
     transfer the owed PT
     * @dev inner working of this function:
     - market.swap is called
     - SCY is transferred to the receiver, and the router's callback is invoked
     - the router will transfer the necessary PT from msg.sender to the market, and finish the callback
     */
    function _swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        if (doPull) {
            address PT = IPMarket(market).PT();
            IERC20(PT).safeTransferFrom(msg.sender, market, exactPtIn);
        }

        (netScyOut, ) = IPMarket(market).swapExactPtForScy(
            receiver,
            exactPtIn,
            minScyOut,
            abi.encode()
        );

        require(netScyOut >= minScyOut, "insufficient scy out");
    }

    function _swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netPtIn) {
        MarketState memory state = IPMarket(market).readState(false);
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        (netPtIn, ) = state.approxSwapPtForExactScy(
            SCYIndexLib.newIndex(SCY),
            exactScyOut,
            block.timestamp,
            approx
        );

        if (doPull) {
            IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);
        }

        IPMarket(market).swapExactPtForScy(receiver, netPtIn, exactScyOut, abi.encode()); // ignore return
    }

    /**
     * @notice swap SCY for exact PT, with receiver receiving PT before msg.sender is required to
     transfer the owed SCY
     * @dev inner working of this function:
     - market.swap is called
     - PT is transferred to the receiver, and the router's callback is invoked
     - the router will transfer the necessary SCY from msg.sender to the market, and finish the callback
     */
    function _swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn,
        bool doPull
    ) internal returns (uint256 netScyIn) {
        MarketState memory state = IPMarket(market).readState(false);
        address SCY = IPMarket(market).SCY();

        (netScyIn, ) = state.swapScyForExactPt(
            SCYIndexLib.newIndex(SCY),
            exactPtOut,
            block.timestamp,
            false
        );
        require(netScyIn <= maxScyIn, "exceed limit scy in");

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, netScyIn);
        }

        IPMarket(market).swapScyForExactPt(receiver, exactPtOut, maxScyIn, abi.encode()); // ignore return
    }

    function _swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netPtOut) {
        MarketState memory state = IPMarket(market).readState(false);
        address SCY = IPMarket(market).SCY();

        (netPtOut, ) = state.approxSwapExactScyForPt(
            SCYIndexLib.newIndex(SCY),
            exactScyIn,
            block.timestamp,
            approx
        );

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, exactScyIn);
        }

        IPMarket(market).swapScyForExactPt(receiver, netPtOut, exactScyIn, abi.encode()); // ignore return
    }
}
