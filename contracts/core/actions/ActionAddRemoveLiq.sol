// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseMintRedeem.sol";
import "../../interfaces/IPActionAddRemoveLiq.sol";
import "../../interfaces/IPMarket.sol";

contract ActionAddRemoveLiq is IPActionAddRemoveLiq, ActionBaseMintRedeem {
    using Math for uint256;
    using Math for int256;
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using SafeERC20 for IERC20;
    using PYIndexLib for IPYieldToken;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberSwapRouter)
        ActionBaseMintRedeem(_kyberSwapRouter) //solhint-disable-next-line no-empty-blocks
    {}

    function addLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 netScyDesired,
        uint256 netPtDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 netPtUsed
        )
    {
        (ISuperComposableYield SCY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market)
            .readTokens();

        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, scyUsed, netPtUsed) = state.addLiquidity(
            YT.newIndex(),
            netScyDesired,
            netPtDesired,
            block.timestamp
        );

        // early-check
        require(netLpOut >= minLpOut, "insufficient lp out");

        IERC20(SCY).safeTransferFrom(msg.sender, market, scyUsed);
        IERC20(PT).safeTransferFrom(msg.sender, market, netPtUsed);

        netLpOut = IPMarket(market).mint(receiver);

        // fail-safe
        require(netLpOut >= minLpOut, "FS insufficient lp out");
        emit AddLiquidityDualScyAndPt(msg.sender, market, receiver, scyUsed, netPtUsed, netLpOut);
    }

    function addLiquidityDualTokenAndPt(
        address receiver,
        address market,
        address tokenIn,
        uint256 netTokenDesired,
        uint256 netPtDesired,
        uint256 minLpOut
    )
        external
        payable
        returns (
            uint256 netLpOut,
            uint256 netTokenUsed,
            uint256 netPtUsed
        )
    {
        (ISuperComposableYield SCY, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market)
            .readTokens();

        uint256 netScyDesired = SCY.previewDeposit(tokenIn, netTokenDesired);
        uint256 scyUsed;

        {
            MarketState memory state = IPMarket(market).readState();
            (, netLpOut, scyUsed, netPtUsed) = state.addLiquidity(
                YT.newIndex(),
                netScyDesired,
                netPtDesired,
                block.timestamp
            );
        }

        // early-check
        require(netLpOut >= minLpOut, "insufficient lp out");

        IERC20(PT).safeTransferFrom(msg.sender, market, netPtUsed);

        // convert tokenIn to SCY to deposit
        netTokenUsed = (netTokenDesired * scyUsed).rawDivUp(netScyDesired);

        if (tokenIn == NATIVE) {
            _transferIn(tokenIn, msg.sender, netTokenDesired);
            SCY.deposit{ value: netTokenUsed }(market, tokenIn, netTokenUsed, scyUsed);
            _transferOut(tokenIn, msg.sender, netTokenDesired - netTokenUsed);
        } else {
            _transferIn(tokenIn, msg.sender, netTokenUsed);
            _safeApproveInf(tokenIn, address(SCY));
            SCY.deposit(market, tokenIn, netTokenUsed, scyUsed);
        }

        netLpOut = IPMarket(market).mint(receiver);
        // fail-safe
        require(netLpOut >= minLpOut, "FS insufficient lp out");

        emit AddLiquidityDualTokenAndPt(
            msg.sender,
            market,
            receiver,
            tokenIn,
            netTokenDesired,
            netPtUsed,
            netLpOut
        );
    }

    function addLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtSwapToScy
    ) external returns (uint256 netLpOut) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtSwap, , ) = state.approxSwapPtToAddLiquidity(
            YT.newIndex(),
            netPtIn,
            block.timestamp,
            guessPtSwapToScy
        );

        IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);

        IPMarket(market).swapExactPtForScy(market, netPtSwap, EMPTY_BYTES); // ignore return, receiver = market
        netLpOut = IPMarket(market).mint(receiver);

        require(netLpOut >= minLpOut, "insufficient lp out");

        emit AddLiquiditySinglePt(msg.sender, market, receiver, netPtIn, netLpOut);
    }

    function addLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy
    ) external returns (uint256 netLpOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();
        IERC20(SCY).safeTransferFrom(msg.sender, market, netScyIn);

        netLpOut = _addLiquiditySingleScy(
            receiver,
            market,
            YT,
            netScyIn,
            minLpOut,
            guessPtReceivedFromScy
        );

        emit AddLiquiditySingleScy(msg.sender, market, receiver, netScyIn, netLpOut);
    }

    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // all output SCY is transferred directly to the market
        uint256 netScyUsed = _mintScyFromToken(address(market), address(SCY), 1, input);

        netLpOut = _addLiquiditySingleScy(
            receiver,
            market,
            YT,
            netScyUsed,
            minLpOut,
            guessPtReceivedFromScy
        );

        emit AddLiquiditySingleToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            input.netTokenIn,
            netLpOut
        );
    }

    function removeLiquidityDualScyAndPt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minScyOut,
        uint256 minPtOut
    ) external returns (uint256 netScyOut, uint256 netPtOut) {
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        (netScyOut, netPtOut) = IPMarket(market).burn(receiver, receiver);

        require(netScyOut >= minScyOut, "insufficient SCY out");
        require(netPtOut >= minPtOut, "insufficient PT out");

        emit RemoveLiquidityDualScyAndPt(
            msg.sender,
            market,
            receiver,
            netLpToRemove,
            netPtOut,
            netScyOut
        );
    }

    function removeLiquidityDualTokenAndPt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        address tokenOut,
        uint256 minTokenOut,
        uint256 minPtOut
    ) external returns (uint256 netTokenOut, uint256 netPtOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        (, netPtOut) = IPMarket(market).burn(address(SCY), receiver);

        netTokenOut = SCY.redeemAfterTransfer(receiver, tokenOut, minTokenOut);

        require(netPtOut >= minPtOut, "insufficient PT out");

        emit RemoveLiquidityDualTokenAndPt(
            msg.sender,
            market,
            receiver,
            netLpToRemove,
            netPtOut,
            tokenOut,
            netTokenOut
        );
    }

    function removeLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut
    ) external returns (uint256 netPtOut) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        MarketState memory state = IPMarket(market).readState();
        (uint256 scyFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);
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
        netPtOut = ptFromBurn + ptFromSwap;

        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, netLpToRemove, netPtOut);
    }

    function removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minScyOut
    ) external returns (uint256 netScyOut) {
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);
        netScyOut = _removeLiquiditySingleScy(receiver, market, minScyOut);
        emit RemoveLiquiditySingleScy(msg.sender, market, receiver, netLpToRemove, netScyOut);
    }

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        // all output SCY is directly transferred to the SCY contract
        uint256 netScyReceived = _removeLiquiditySingleScy(address(SCY), market, 1);

        // since all SCY is already at the SCY contract, doPull = false
        netTokenOut = _redeemScyToToken(receiver, address(SCY), netScyReceived, output, false);

        emit RemoveLiquiditySingleToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            netLpToRemove,
            netTokenOut
        );
    }

    function _addLiquiditySingleScy(
        address receiver,
        address market,
        IPYieldToken YT,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy
    ) internal returns (uint256 netLpOut) {
        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtReceived, , ) = state.approxSwapScyToAddLiquidity(
            YT.newIndex(),
            netScyIn,
            block.timestamp,
            guessPtReceivedFromScy
        );

        IPMarket(market).swapScyForExactPt(market, netPtReceived, EMPTY_BYTES); // ignore return, receiver = market
        netLpOut = IPMarket(market).mint(receiver);

        require(netLpOut >= minLpOut, "insufficient lp out");
    }

    function _removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 minScyOut
    ) internal returns (uint256 netScyOut) {
        (uint256 scyFromBurn, uint256 ptFromBurn) = IPMarket(market).burn(receiver, market);
        (uint256 scyFromSwap, ) = IPMarket(market).swapExactPtForScy(
            receiver,
            ptFromBurn,
            EMPTY_BYTES
        );

        require(scyFromBurn + scyFromSwap >= minScyOut, "insufficient lp out");
        netScyOut = scyFromBurn + scyFromSwap;
    }
}
