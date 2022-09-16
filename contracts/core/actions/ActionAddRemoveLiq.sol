// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./base/ActionBaseMintRedeem.sol";
import "../../interfaces/IPActionAddRemoveLiq.sol";
import "../../interfaces/IPMarket.sol";
import "../../libraries/Errors.sol";

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
            uint256 netScyUsed,
            uint256 netPtUsed
        )
    {
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, netScyUsed, netPtUsed) = state.addLiquidity(
            netScyDesired,
            netPtDesired,
            block.timestamp
        );

        // early-check
        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        IERC20(SCY).safeTransferFrom(msg.sender, market, netScyUsed);
        IERC20(PT).safeTransferFrom(msg.sender, market, netPtUsed);

        (netLpOut, , ) = IPMarket(market).mint(receiver, netScyUsed, netPtUsed);

        // fail-safe
        if (netLpOut < minLpOut) assert(false);

        emit AddLiquidityDualScyAndPt(
            msg.sender,
            market,
            receiver,
            netScyUsed,
            netPtUsed,
            netLpOut
        );
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
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        uint256 netScyDesired = SCY.previewDeposit(tokenIn, netTokenDesired);
        uint256 netScyUsed;

        {
            MarketState memory state = IPMarket(market).readState();
            (, netLpOut, netScyUsed, netPtUsed) = state.addLiquidity(
                netScyDesired,
                netPtDesired,
                block.timestamp
            );
        }

        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        IERC20(PT).safeTransferFrom(msg.sender, market, netPtUsed);

        // convert tokenIn to SCY to deposit
        netTokenUsed = (netTokenDesired * netScyUsed).rawDivUp(netScyDesired);

        if (tokenIn == NATIVE) {
            _transferIn(tokenIn, msg.sender, netTokenDesired);
            SCY.deposit{ value: netTokenUsed }(market, tokenIn, netTokenUsed, netScyUsed);
            _transferOut(tokenIn, msg.sender, netTokenDesired - netTokenUsed);
        } else {
            _transferIn(tokenIn, msg.sender, netTokenUsed);
            _safeApproveInf(tokenIn, address(SCY));
            SCY.deposit(market, tokenIn, netTokenUsed, netScyUsed);
        }

        (netLpOut, , ) = IPMarket(market).mint(receiver, netScyUsed, netPtUsed);

        if (netLpOut < minLpOut) assert(false);

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
    ) external returns (uint256 netLpOut, uint256 netScyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtSwap, , ) = state.approxSwapPtToAddLiquidity(
            YT.newIndex(),
            netPtIn,
            block.timestamp,
            guessPtSwapToScy
        );

        IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);

        uint256 netScyReceived;
        (netScyReceived, netScyFee) = IPMarket(market).swapExactPtForScy(
            market,
            netPtSwap,
            EMPTY_BYTES
        ); // ignore return, receiver = market

        (netLpOut, , ) = IPMarket(market).mint(receiver, netScyReceived, netPtIn - netPtSwap);

        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        emit AddLiquiditySinglePt(msg.sender, market, receiver, netPtIn, netLpOut);
    }

    function addLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netScyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromScy
    ) external returns (uint256 netLpOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();
        IERC20(SCY).safeTransferFrom(msg.sender, market, netScyIn);

        (netLpOut, netScyFee) = _addLiquiditySingleScy(
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
    ) external payable returns (uint256 netLpOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // all output SCY is transferred directly to the market
        uint256 netScyUsed = _mintScyFromToken(address(market), address(SCY), 1, input);

        (netLpOut, netScyFee) = _addLiquiditySingleScy(
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

        (netScyOut, netPtOut) = IPMarket(market).burn(receiver, receiver, netLpToRemove);

        if (netScyOut < minScyOut) revert Errors.RouterInsufficientScyOut(netScyOut, minScyOut);
        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

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

        uint256 netScyOut;
        (netScyOut, netPtOut) = IPMarket(market).burn(address(SCY), receiver, netLpToRemove);

        netTokenOut = SCY.redeem(receiver, netScyOut, tokenOut, minTokenOut, true);

        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

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
    ) external returns (uint256 netPtOut, uint256 netScyFee) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        MarketState memory state = IPMarket(market).readState();
        (uint256 scyFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);
        (uint256 ptFromSwap, ) = state.approxSwapExactScyForPt(
            YT.newIndex(),
            scyFromBurn,
            block.timestamp,
            guessPtOut
        );

        if (ptFromBurn + ptFromSwap < minPtOut)
            revert Errors.RouterInsufficientPtOut(ptFromBurn + ptFromSwap, minPtOut);

        (, ptFromBurn) = IPMarket(market).burn(market, receiver, netLpToRemove);
        (, netScyFee) = IPMarket(market).swapScyForExactPt(receiver, ptFromSwap, EMPTY_BYTES);

        // fail-safe
        if (ptFromBurn + ptFromSwap < minPtOut) assert(false);

        netPtOut = ptFromBurn + ptFromSwap;

        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, netLpToRemove, netPtOut);
    }

    function removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minScyOut
    ) external returns (uint256 netScyOut, uint256 netScyFee) {
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);
        (netScyOut, netScyFee) = _removeLiquiditySingleScy(
            receiver,
            market,
            netLpToRemove,
            minScyOut
        );
        emit RemoveLiquiditySingleScy(msg.sender, market, receiver, netLpToRemove, netScyOut);
    }

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        // all output SCY is directly transferred to the SCY contract
        uint256 netScyReceived;

        (netScyReceived, netScyFee) = _removeLiquiditySingleScy(
            address(SCY),
            market,
            netLpToRemove,
            1
        );

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
    ) internal returns (uint256 netLpOut, uint256 netScyFee) {
        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtReceived, , ) = state.approxSwapScyToAddLiquidity(
            YT.newIndex(),
            netScyIn,
            block.timestamp,
            guessPtReceivedFromScy
        );

        uint256 netScySwapped;
        (netScySwapped, netScyFee) = IPMarket(market).swapScyForExactPt(
            market,
            netPtReceived,
            EMPTY_BYTES
        ); // ignore return, receiver = market
        (netLpOut, , ) = IPMarket(market).mint(receiver, netScyIn - netScySwapped, netPtReceived);

        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);
    }

    function _removeLiquiditySingleScy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minScyOut
    ) internal returns (uint256 netScyOut, uint256 netScyFee) {
        if (IPMarket(market).isExpired()) {
            netScyOut = __removeLpToScyAfterExpiry(receiver, market, netLpToRemove);
        } else {
            (netScyOut, netScyFee) = __removeLpToScyBeforeExpiry(receiver, market, netLpToRemove);
        }

        if (netScyOut < minScyOut) revert Errors.RouterInsufficientScyOut(netScyOut, minScyOut);
    }

    function __removeLpToScyAfterExpiry(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netScyOut) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (uint256 scyFromBurn, ) = IPMarket(market).burn(receiver, address(YT), netLpToRemove);
        netScyOut = scyFromBurn + IPYieldToken(YT).redeemPY(receiver);
    }

    function __removeLpToScyBeforeExpiry(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netScyOut, uint256 netScyFee) {
        (uint256 scyFromBurn, uint256 ptFromBurn) = IPMarket(market).burn(
            receiver,
            market,
            netLpToRemove
        );

        uint256 scyFromSwap;
        (scyFromSwap, netScyFee) = IPMarket(market).swapExactPtForScy(
            receiver,
            ptFromBurn,
            EMPTY_BYTES
        );
        netScyOut = scyFromBurn + scyFromSwap;
    }
}
