// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../../../interfaces/IPMarketFactory.sol";
import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPMarketSwapCallback.sol";
import "../../../libraries/math/MarketApproxLib.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ActionSCYAndPYBase.sol";

abstract contract ActionSCYAndPTBase is ActionSCYAndPYBase {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketApproxLib for MarketState;
    using SafeERC20 for IERC20;
    using PYIndexLib for IPYieldToken;

    bytes private constant EMPTY_BYTES = abi.encode();

    /// @dev since this contract will be proxied, it must not contains non-immutable variables

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

        _transferIn(tokenIn, msg.sender, tokenUsed);

        _safeApproveInf(tokenIn, address(SCY));

        SCY.deposit{ value: tokenIn == NATIVE ? msg.value : 0 }(
            market,
            tokenIn,
            tokenUsed,
            scyUsed
        );

        netLpOut = IPMarket(market).mint(receiver);
        // fail-safe
        require(netLpOut >= minLpOut, "FS insufficient lp out");
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

    function _swapExactPtForScy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minScyOut,
        bool doPull
    ) internal returns (uint256 netScyOut) {
        if (doPull) {
            (, IPPrincipalToken PT, ) = IPMarket(market).readTokens();
            IERC20(address(PT)).safeTransferFrom(msg.sender, market, exactPtIn);
        }

        (netScyOut, ) = IPMarket(market).swapExactPtForScy(receiver, exactPtIn, EMPTY_BYTES);

        require(netScyOut >= minScyOut, "insufficient SCY out");
    }

    /**
     * @notice Note that the amount of SCY out will be a bit more than `exactScyOut`, since an approximation is used. It's
        guaranteed that the `netScyOut` is at least `exactScyOut`
     */
    function _swapPtForExactScy(
        address receiver,
        address market,
        uint256 exactScyOut,
        uint256 maxPtIn,
        ApproxParams memory guessPtIn,
        bool doPull
    ) internal returns (uint256 netPtIn) {
        MarketState memory state = IPMarket(market).readState(false);
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        (netPtIn, , ) = state.approxSwapPtForExactScy(
            YT.newIndex(),
            exactScyOut,
            block.timestamp,
            guessPtIn
        );
        require(netPtIn <= maxPtIn, "exceed limit PT in");

        if (doPull) {
            IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);
        }

        (uint256 netScyOut, ) = IPMarket(market).swapExactPtForScy(receiver, netPtIn, EMPTY_BYTES);

        // fail-safe
        require(netScyOut >= exactScyOut, "FS insufficient SCY out");
    }

    function _swapScyForExactPt(
        address receiver,
        address market,
        uint256 exactPtOut,
        uint256 maxScyIn,
        bool doPull
    ) internal returns (uint256 netScyIn) {
        MarketState memory state = IPMarket(market).readState(false);
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netScyIn, ) = state.swapScyForExactPt(YT.newIndex(), exactPtOut, block.timestamp);

        require(netScyIn <= maxScyIn, "exceed limit SCY in");

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, netScyIn);
        }

        IPMarket(market).swapScyForExactPt(receiver, exactPtOut, EMPTY_BYTES); // ignore return

        // no fail-safe since exactly netScyIn will go into the market
    }

    /**
     * @notice Note that although we will only use almost all of the `exactScyIn`, we will still transfer all in so that
        not to leave dust behind
     */
    function _swapExactScyForPt(
        address receiver,
        address market,
        uint256 exactScyIn,
        uint256 minPtOut,
        ApproxParams memory guessPtOut,
        bool doPull
    ) internal returns (uint256 netPtOut) {
        MarketState memory state = IPMarket(market).readState(false);
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        (netPtOut, , ) = state.approxSwapExactScyForPt(
            YT.newIndex(),
            exactScyIn,
            block.timestamp,
            guessPtOut
        );

        require(netPtOut >= minPtOut, "insufficient PT out");

        if (doPull) {
            IERC20(SCY).safeTransferFrom(msg.sender, market, exactScyIn);
        }

        IPMarket(market).swapScyForExactPt(receiver, netPtOut, EMPTY_BYTES); // ignore return

        // no fail-safe since exactly netPtOut >= minPtOut will be out
    }

    /**
     * @notice swap from any ERC20 tokens, through Uniswap's forks, to get baseTokens to make SCY, then swap
        from SCY to PT
     * @dev simply a combination of _mintScyFromToken & _swapExactScyForPt
     */
    function _swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams memory guessPtOut,
        TokenInput calldata input
    ) internal returns (uint256 netPtOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        // all output SCY is transferred directly to the market
        uint256 netScyUseToBuyPt = _mintScyFromToken(address(market), address(SCY), 1, input);

        // SCY is already in the market, hence doPull = false
        netPtOut = _swapExactScyForPt(
            receiver,
            market,
            netScyUseToBuyPt,
            minPtOut,
            guessPtOut,
            false
        );
    }

    /**
     * @notice swap from PT to SCY, then redeem SCY to baseToken & swap through Uniswap's forks to get tokenOut
     * @dev simply a combination of _swapExactPtForScy & _redeemScyToToken
     */
    function _swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        bool doPull
    ) internal returns (uint256 netTokenOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        // all output SCY is directly transferred to the SCY contract
        uint256 netScyReceived = _swapExactPtForScy(address(SCY), market, exactPtIn, 1, doPull);

        // since all SCY is already at the SCY contract, doPull = false
        netTokenOut = _redeemScyToToken(receiver, address(SCY), netScyReceived, output, false);
    }
}
