// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/IPMarket.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "./ActionBaseTokenSCY.sol";

abstract contract ActionBaseAddRemoveLiq is ActionBaseTokenSCY {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketApproxLib for MarketState;
    using SafeERC20 for IERC20;
    using PYIndexLib for IPYieldToken;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter) ActionBaseTokenSCY(_kyberSwapRouter) {}

    /// @dev For doPull: if doPull is true, this function will do transferFrom as necessary from msg.sender. Else, it will
    /// assume tokens have already been transferred in.

    function _addLiquidityDualScyAndPt(
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
        (ISuperComposableYield SCY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market)
            .readTokens();

        MarketState memory state = IPMarket(market).readState(false);
        (, netLpOut, scyUsed, ptUsed) = state.addLiquidity(
            YT.newIndex(),
            scyDesired,
            ptDesired,
            block.timestamp
        );

        // early-check
        require(netLpOut >= minLpOut, "insufficient lp out");

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, scyUsed);
            IERC20(PT).safeTransferFrom(msg.sender, market, ptUsed);
        }

        netLpOut = IPMarket(market).mint(receiver);

        // fail-safe
        require(netLpOut >= minLpOut, "FS insufficient lp out");
    }

    function _addLiquidityDualTokenAndPt(
        address receiver,
        address market,
        address tokenIn,
        uint256 tokenDesired,
        uint256 ptDesired,
        uint256 minLpOut
    )
        internal
        returns (
            uint256 netLpOut,
            uint256 tokenUsed,
            uint256 ptUsed
        )
    {
        (ISuperComposableYield SCY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market)
            .readTokens();

        uint256 scyDesired = SCY.previewDeposit(tokenIn, tokenDesired);
        uint256 scyUsed;

        {
            MarketState memory state = IPMarket(market).readState(false);
            (, netLpOut, scyUsed, ptUsed) = state.addLiquidity(
                YT.newIndex(),
                scyDesired,
                ptDesired,
                block.timestamp
            );
        }

        // early-check
        require(netLpOut >= minLpOut, "insufficient lp out");

        IERC20(PT).safeTransferFrom(msg.sender, market, ptUsed);

        // convert tokenIn to SCY to deposit
        tokenUsed = (tokenDesired * scyUsed).rawDivUp(scyDesired);

        if (tokenIn == NATIVE) {
            _transferIn(tokenIn, msg.sender, tokenDesired);
            SCY.deposit{ value: tokenUsed }(market, tokenIn, tokenUsed, scyUsed);
            _transferOut(tokenIn, msg.sender, tokenDesired - tokenUsed);
        } else {
            _transferIn(tokenIn, msg.sender, tokenUsed);
            _safeApproveInf(tokenIn, address(SCY));
            SCY.deposit(market, tokenIn, tokenUsed, scyUsed);
        }

        netLpOut = IPMarket(market).mint(receiver);
        // fail-safe
        require(netLpOut >= minLpOut, "FS insufficient lp out");
    }

    function _addLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtSwapToScy,
        bool doPull
    ) internal returns (uint256 netLpOut) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState(false);

        (uint256 netPtSwap, , ) = state.approxSwapPtToAddLiquidity(
            YT.newIndex(),
            netPtIn,
            block.timestamp,
            guessPtSwapToScy
        );

        if (doPull) {
            IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);
        }

        IPMarket(market).swapExactPtForScy(market, netPtSwap, EMPTY_BYTES); // ignore return, receiver = market
        netLpOut = IPMarket(market).mint(receiver);

        require(netLpOut >= minLpOut, "insufficient lp out");
    }

    function _addLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy,
        bool doPull
    ) internal returns (uint256 netLpOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState(false);

        (uint256 netPtReceived, , ) = state.approxSwapScyToAddLiquidity(
            YT.newIndex(),
            netScyIn,
            block.timestamp,
            guessPtReceivedFromScy
        );

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, netScyIn);
        }

        IPMarket(market).swapScyForExactPt(market, netPtReceived, EMPTY_BYTES); // ignore return, receiver = market
        netLpOut = IPMarket(market).mint(receiver);

        require(netLpOut >= minLpOut, "insufficient lp out");
    }

    function _addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy,
        TokenInput calldata input
    ) internal returns (uint256 netLpOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        // all output SCY is transferred directly to the market
        uint256 netScyUsed = _mintScyFromToken(address(market), address(SCY), 1, input);

        // SCY is already in the market, hence doPull = false
        netLpOut = _addLiquiditySingleScy(
            receiver,
            market,
            netScyUsed,
            minLpOut,
            guessPtReceivedFromScy,
            false
        );
    }

    function _removeLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 scyOutMin,
        uint256 ptOutMin
    ) internal returns (uint256 netScyOut, uint256 netPtOut) {
        IERC20(market).safeTransferFrom(msg.sender, market, lpToRemove);

        (netScyOut, netPtOut) = IPMarket(market).burn(receiver, receiver);

        require(netScyOut >= scyOutMin, "insufficient SCY out");
        require(netPtOut >= ptOutMin, "insufficient PT out");
    }

    function _removeLiquidityDualTokenAndPt(
        address receiver,
        address market,
        uint256 lpToRemove,
        address tokenOut,
        uint256 tokenOutMin,
        uint256 ptOutMin
    ) internal returns (uint256 netTokenOut, uint256 netPtOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, lpToRemove);

        (, netPtOut) = IPMarket(market).burn(address(SCY), receiver);

        netTokenOut = SCY.redeemAfterTransfer(receiver, tokenOut, tokenOutMin);

        require(netPtOut >= ptOutMin, "insufficient PT out");
    }

    function _removeLiquiditySinglePt(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    )
        internal
        returns (
            uint256 /*netPtOut*/
        )
    {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, lpToRemove);

        MarketState memory state = IPMarket(market).readState(false);
        (uint256 scyFromBurn, uint256 ptFromBurn) = state.removeLiquidity(lpToRemove);
        (uint256 ptFromSwap, , ) = state.approxSwapExactScyForPt(
            YT.newIndex(),
            scyFromBurn,
            block.timestamp,
            guessPtOut
        );

        // early-check
        require(ptFromBurn + ptFromSwap >= minPtOut, "insufficient lp out");

        (, ptFromBurn) = IPMarket(market).burn(market, receiver);
        IPMarket(market).swapScyForExactPt(receiver, ptFromSwap, EMPTY_BYTES); // ignore return

        // fail-safe
        require(ptFromBurn + ptFromSwap >= minPtOut, "FS insufficient lp out");
        return ptFromBurn + ptFromSwap;
    }

    function _removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 lpToRemove,
        uint256 minScyOut
    )
        internal
        returns (
            uint256 /*netScyOut*/
        )
    {
        IERC20(market).safeTransferFrom(msg.sender, market, lpToRemove);

        (uint256 scyFromBurn, uint256 ptFromBurn) = IPMarket(market).burn(receiver, market);
        (uint256 scyFromSwap, ) = IPMarket(market).swapExactPtForScy(
            receiver,
            ptFromBurn,
            EMPTY_BYTES
        );

        require(scyFromBurn + scyFromSwap >= minScyOut, "insufficient lp out");
        return scyFromBurn + scyFromSwap;
    }

    function _removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 lpToRemove,
        TokenOutput calldata output
    ) internal returns (uint256 netTokenOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        // all output SCY is directly transferred to the SCY contract
        uint256 netScyReceived = _removeLiquiditySingleScy(address(SCY), market, lpToRemove, 1);

        // since all SCY is already at the SCY contract, doPull = false
        netTokenOut = _redeemScyToToken(receiver, address(SCY), netScyReceived, output, false);
    }
}
