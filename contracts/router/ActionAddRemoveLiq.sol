// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./base/ActionBaseMintRedeem.sol";
import "../interfaces/IPActionAddRemoveLiq.sol";
import "../interfaces/IPMarket.sol";
import "../core/libraries/Errors.sol";

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

    function addLiquidityDualSyAndPt(
        address receiver,
        address market,
        uint256 netSyDesired,
        uint256 netPtDesired,
        uint256 minLpOut
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netSyUsed,
            uint256 netPtUsed
        )
    {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(
            netSyDesired,
            netPtDesired,
            block.timestamp
        );

        // early-check
        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        IERC20(SY).safeTransferFrom(msg.sender, market, netSyUsed);
        IERC20(PT).safeTransferFrom(msg.sender, market, netPtUsed);

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyUsed, netPtUsed);

        // fail-safe
        if (netLpOut < minLpOut) assert(false);

        emit AddLiquidityDualSyAndPt(msg.sender, market, receiver, netSyUsed, netPtUsed, netLpOut);
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
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        uint256 netSyDesired = SY.previewDeposit(tokenIn, netTokenDesired);
        uint256 netSyUsed;

        {
            MarketState memory state = IPMarket(market).readState();
            (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(
                netSyDesired,
                netPtDesired,
                block.timestamp
            );
        }

        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        IERC20(PT).safeTransferFrom(msg.sender, market, netPtUsed);

        // convert tokenIn to SY to deposit
        netTokenUsed = (netTokenDesired * netSyUsed).rawDivUp(netSyDesired);

        if (tokenIn == NATIVE) {
            _transferIn(tokenIn, msg.sender, netTokenDesired);
            SY.deposit{ value: netTokenUsed }(market, tokenIn, netTokenUsed, netSyUsed);
            _transferOut(tokenIn, msg.sender, netTokenDesired - netTokenUsed);
        } else {
            _transferIn(tokenIn, msg.sender, netTokenUsed);
            _safeApproveInf(tokenIn, address(SY));
            SY.deposit(market, tokenIn, netTokenUsed, netSyUsed);
        }

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyUsed, netPtUsed);

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
        ApproxParams calldata guessPtSwapToSy
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();

        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtSwap, , ) = state.approxSwapPtToAddLiquidity(
            YT.newIndex(),
            netPtIn,
            block.timestamp,
            guessPtSwapToSy
        );

        IERC20(PT).safeTransferFrom(msg.sender, market, netPtIn);

        uint256 netSyReceived;
        (netSyReceived, netSyFee) = IPMarket(market).swapExactPtForSy(
            market,
            netPtSwap,
            EMPTY_BYTES
        ); // ignore return, receiver = market

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyReceived, netPtIn - netPtSwap);

        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        emit AddLiquiditySinglePt(msg.sender, market, receiver, netPtIn, netLpOut);
    }

    function addLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();
        IERC20(SY).safeTransferFrom(msg.sender, market, netSyIn);

        (netLpOut, netSyFee) = _addLiquiditySingleSy(
            receiver,
            market,
            YT,
            netSyIn,
            minLpOut,
            guessPtReceivedFromSy
        );

        emit AddLiquiditySingleSy(msg.sender, market, receiver, netSyIn, netLpOut);
    }

    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut, uint256 netSyFee) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        // all output SY is transferred directly to the market
        uint256 netSyUsed = _mintSyFromToken(address(market), address(SY), 1, input);

        (netLpOut, netSyFee) = _addLiquiditySingleSy(
            receiver,
            market,
            YT,
            netSyUsed,
            minLpOut,
            guessPtReceivedFromSy
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

    function removeLiquidityDualSyAndPt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut,
        uint256 minPtOut
    ) external returns (uint256 netSyOut, uint256 netPtOut) {
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        (netSyOut, netPtOut) = IPMarket(market).burn(receiver, receiver, netLpToRemove);

        if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut);
        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

        emit RemoveLiquidityDualSyAndPt(
            msg.sender,
            market,
            receiver,
            netLpToRemove,
            netPtOut,
            netSyOut
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
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        uint256 netSyOut;
        (netSyOut, netPtOut) = IPMarket(market).burn(address(SY), receiver, netLpToRemove);

        netTokenOut = SY.redeem(receiver, netSyOut, tokenOut, minTokenOut, true);

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
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        MarketState memory state = IPMarket(market).readState();
        (uint256 syFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);
        (uint256 ptFromSwap, ) = state.approxSwapExactSyForPt(
            YT.newIndex(),
            syFromBurn,
            block.timestamp,
            guessPtOut
        );

        if (ptFromBurn + ptFromSwap < minPtOut)
            revert Errors.RouterInsufficientPtOut(ptFromBurn + ptFromSwap, minPtOut);

        (, ptFromBurn) = IPMarket(market).burn(market, receiver, netLpToRemove);
        (, netSyFee) = IPMarket(market).swapSyForExactPt(receiver, ptFromSwap, EMPTY_BYTES);

        // fail-safe
        if (ptFromBurn + ptFromSwap < minPtOut) assert(false);

        netPtOut = ptFromBurn + ptFromSwap;

        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, netLpToRemove, netPtOut);
    }

    function removeLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);
        (netSyOut, netSyFee) = _removeLiquiditySingleSy(receiver, market, netLpToRemove, minSyOut);
        emit RemoveLiquiditySingleSy(msg.sender, market, receiver, netLpToRemove, netSyOut);
    }

    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut, uint256 netSyFee) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();

        IERC20(market).safeTransferFrom(msg.sender, market, netLpToRemove);

        // all output SY is directly transferred to the SY contract
        uint256 netSyReceived;

        (netSyReceived, netSyFee) = _removeLiquiditySingleSy(
            address(SY),
            market,
            netLpToRemove,
            1
        );

        // since all SY is already at the SY contract, doPull = false
        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyReceived, output, false);

        emit RemoveLiquiditySingleToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            netLpToRemove,
            netTokenOut
        );
    }

    function _addLiquiditySingleSy(
        address receiver,
        address market,
        IPYieldToken YT,
        uint256 netSyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy
    ) internal returns (uint256 netLpOut, uint256 netSyFee) {
        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtReceived, , ) = state.approxSwapSyToAddLiquidity(
            YT.newIndex(),
            netSyIn,
            block.timestamp,
            guessPtReceivedFromSy
        );

        uint256 netSySwapped;
        (netSySwapped, netSyFee) = IPMarket(market).swapSyForExactPt(
            market,
            netPtReceived,
            EMPTY_BYTES
        ); // ignore return, receiver = market
        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyIn - netSySwapped, netPtReceived);

        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);
    }

    function _removeLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        if (IPMarket(market).isExpired()) {
            netSyOut = __removeLpToSyAfterExpiry(receiver, market, netLpToRemove);
        } else {
            (netSyOut, netSyFee) = __removeLpToSyBeforeExpiry(receiver, market, netLpToRemove);
        }

        if (netSyOut < minSyOut) revert Errors.RouterInsufficientSyOut(netSyOut, minSyOut);
    }

    function __removeLpToSyAfterExpiry(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netSyOut) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (uint256 syFromBurn, ) = IPMarket(market).burn(receiver, address(YT), netLpToRemove);
        netSyOut = syFromBurn + IPYieldToken(YT).redeemPY(receiver);
    }

    function __removeLpToSyBeforeExpiry(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        (uint256 syFromBurn, uint256 ptFromBurn) = IPMarket(market).burn(
            receiver,
            market,
            netLpToRemove
        );

        uint256 syFromSwap;
        (syFromSwap, netSyFee) = IPMarket(market).swapExactPtForSy(
            receiver,
            ptFromBurn,
            EMPTY_BYTES
        );
        netSyOut = syFromBurn + syFromSwap;
    }
}
