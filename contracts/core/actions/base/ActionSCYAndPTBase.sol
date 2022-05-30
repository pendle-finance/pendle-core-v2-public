// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPMarketAddRemoveCallback.sol";
import "../../../interfaces/IPMarketSwapCallback.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "../../../libraries/math/MarketMathAux.sol";
import "../../../libraries/math/MarketAddSingleLib.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ActionSCYAndPTBase {
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
     - the router will transfer the necessary scy & pt from msg.sender to the market, and finish the callback
     */
    function _addLiquidity(
        address receiver,
        address market,
        uint256 scyDesired,
        uint256 ptDesired,
        uint256 minLpOut,
        bool doPull
    )
        internal
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 ptUsed
        )
    {
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState(false);
        (, netLpOut, scyUsed, ptUsed) = state.addLiquidity(
            SCYIndexLib.newIndex(SCY),
            scyDesired,
            ptDesired,
            false
        );

        require(netLpOut >= minLpOut, "insufficient lp out");

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, scyUsed);
            IERC20(PT).safeTransferFrom(msg.sender, market, ptUsed);
        }

        IPMarket(market).addLiquidity(receiver, ptDesired, scyDesired, abi.encode()); // ignore return
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
        uint256 ptOutMin,
        bool doPull
    ) internal returns (uint256 netScyOut, uint256 netPtOut) {
        MarketState memory state = IPMarket(market).readState(false);

        (netScyOut, netPtOut) = state.removeLiquidity(lpToRemove, false);
        require(netScyOut >= scyOutMin, "insufficient scy out");
        require(netPtOut >= ptOutMin, "insufficient pt out");

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

    /**
     * @notice swap PT for exact SCY, with receiver receiving SCY before msg.sender is required to
     transfer the owed PT
     * @dev inner working of this function is similar to swapExactPtForScy
     * @param approx params to approx. Guess params will be the min, max & offchain guess for netPtIn
     */
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

    /**
     * @dev swap exact amount of Scy to PT
     * @dev inner working steps:
       - The outcome amount of PT in is approximated
       - market.swapExactPtToScy() is called, user will receive their PT
       - The approximated amount of PT is transferred from msg.sender to market via router
     * @param approx params to approx. Guess params will be the min, max & offchain guess for netPtOut
     */
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

    /**
     * @dev the precomputation will be skipped for this function since we will not be able to know
     * the state of the market after the swap is done (before performing add liquidity).
     */
    function _addLiquiditySinglePT(
        address receiver,
        address market,
        uint256 ptIn,
        uint256 minLpOut,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netLpOut) {
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        if (doPull) {
            IERC20(PT).safeTransferFrom(msg.sender, market, ptIn);
        }

        MarketState memory state = IPMarket(market).readState(false);
        uint256 ptToSwap = MarketAddSingleLib.approxAddSingleLiquidityPT(
            state,
            SCYIndexLib.newIndex(SCY),
            ptIn,
            block.timestamp,
            approx
        );
        (uint256 scyToAdd, ) = IPMarket(market).swapExactPtForScy(
            market,
            ptToSwap,
            0,
            abi.encode()
        );
        uint256 ptToAdd = ptIn - ptToSwap;

        (netLpOut, , ) = IPMarket(market).addLiquidity(receiver, scyToAdd, ptToAdd, abi.encode());
        require(netLpOut >= minLpOut, "insufficient lp out");
    }

    function _addLiquiditySingleSCY(
        address receiver,
        address market,
        uint256 scyIn,
        uint256 minLpOut,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netLpOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, scyIn);
        }

        MarketState memory state = IPMarket(market).readState(false);
        uint256 ptToAdd = MarketAddSingleLib.approxAddSingleLiquiditySCY(
            state,
            SCYIndexLib.newIndex(SCY),
            scyIn,
            block.timestamp,
            approx
        );
        (uint256 scyToSwap, ) = IPMarket(market).swapScyForExactPt(
            market,
            ptToAdd,
            0,
            abi.encode()
        );

        uint256 scyToAdd = scyIn - scyToSwap;

        (netLpOut, , ) = IPMarket(market).addLiquidity(receiver, scyToAdd, ptToAdd, abi.encode());
        require(netLpOut >= minLpOut, "insufficient lp out");
    }

    function _removeLiquiditySinglePT(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minPtOut,
        ApproxParams memory approx,
        bool doPull
    ) internal returns (uint256 netPtOut) {
        if (doPull) {
            IERC20(market).safeTransferFrom(msg.sender, market, lpToRemove);
        }

        (uint256 netScyRemoved, uint256 netPtRemoved) = IPMarket(market).removeLiquidity(
            market,
            receiver,
            lpToRemove,
            abi.encode()
        );
        uint256 netPtSwapped = _swapExactScyForPt(receiver, market, netScyRemoved, approx, false);

        netPtOut = netPtRemoved + netPtSwapped;
        require(netPtOut >= minPtOut, "insufficient pt out");
    }

    function _removeLiquiditySingleSCY(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minScyOut,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        if (doPull) {
            IERC20(market).safeTransferFrom(msg.sender, market, lpToRemove);
        }
        (uint256 netScyRemoved,) = IPMarket(market).removeLiquidity(
            receiver,
            market,
            lpToRemove,
            abi.encode()
        );
        uint256 netScySwapped = _swapExactPtForScy(receiver, market, netScyRemoved, 0, false);

        netScyOut = netScyRemoved + netScySwapped;
        require(netScyOut >= minScyOut, "insufficient scy out");
    }
}
