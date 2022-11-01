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
    using PYIndexLib for IPYieldToken;
    using BulkSellerMathCore for BulkSellerState;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _kyberScalingLib, address _bulkSellerDirectory)
        ActionBaseMintRedeem(_kyberScalingLib, _bulkSellerDirectory) //solhint-disable-next-line no-empty-blocks
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

        // calculate the amount of SY and PT to be used
        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(
            netSyDesired,
            netPtDesired,
            block.timestamp
        );

        // early-check
        if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

        // execute the addLiquidity
        _transferFrom(IERC20(SY), msg.sender, market, netSyUsed);
        _transferFrom(IERC20(PT), msg.sender, market, netPtUsed);

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyUsed, netPtUsed);

        // fail-safe
        if (netLpOut < minLpOut) assert(false);

        emit AddLiquidityDualSyAndPt(msg.sender, market, receiver, netSyUsed, netPtUsed, netLpOut);
    }

    /**
     * @dev this function assumes that netTokenDesired = netTokenUsed, and fails if this does not hold
     */
    function addLiquidityDualTokenAndPt(
        address receiver,
        address market,
        TokenInput calldata input,
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

        uint256 netSyDesired = _mintSyFromToken(market, address(SY), 1, input);
        uint256 netSyUsed;

        {
            // calc the amount of SY and PT to be used
            MarketState memory state = IPMarket(market).readState();
            (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(
                netSyDesired,
                netPtDesired,
                block.timestamp
            );

            if (netSyDesired != netSyUsed)
                revert Errors.RouterNotAllSyUsed(netSyDesired, netSyUsed);
            if (netLpOut < minLpOut) revert Errors.RouterInsufficientLpOut(netLpOut, minLpOut);

            netTokenUsed = input.netTokenIn;
        }

        // SY has been minted and transferred to the market
        _transferFrom(IERC20(PT), msg.sender, market, netPtUsed);
        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyUsed, netPtUsed);

        // fail-safe
        if (netLpOut < minLpOut) assert(false);

        emit AddLiquidityDualTokenAndPt(
            msg.sender,
            market,
            receiver,
            input.tokenIn,
            netTokenUsed,
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

        // calculate the amount of PT to swap
        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtSwap, , ) = state.approxSwapPtToAddLiquidity(
            YT.newIndex(),
            netPtIn,
            block.timestamp,
            guessPtSwapToSy
        );

        // execute the swap
        _transferFrom(IERC20(PT), msg.sender, market, netPtIn);

        uint256 netSyReceived;
        (netSyReceived, netSyFee) = IPMarket(market).swapExactPtForSy(
            market,
            netPtSwap,
            EMPTY_BYTES
        );

        // execute the addLiquidity
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

        // transfer SY to market
        _transferFrom(IERC20(SY), msg.sender, market, netSyIn);

        // mint LP
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

        // mint SY directly to the market
        uint256 netSyUsed = _mintSyFromToken(market, address(SY), 1, input);

        // mint LP
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
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

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
        TokenOutput calldata output,
        uint256 minPtOut
    ) external returns (uint256 netTokenOut, uint256 netPtOut) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();

        // burn LP, SY sent to either SY or bulk, PT sent to receiver
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        uint256 netSyOut;
        (netSyOut, netPtOut) = IPMarket(market).burn(
            _syOrBulk(address(SY), output),
            receiver,
            netLpToRemove
        );

        if (netPtOut < minPtOut) revert Errors.RouterInsufficientPtOut(netPtOut, minPtOut);

        // redeem SY to token
        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyOut, output, false);

        emit RemoveLiquidityDualTokenAndPt(
            msg.sender,
            market,
            receiver,
            netLpToRemove,
            netPtOut,
            output.tokenOut,
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

        // calculate the total amount of PT received from burning & selling SY
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

        // execute the burn & the swap
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        (, ptFromBurn) = IPMarket(market).burn(market, receiver, netLpToRemove);
        (, netSyFee) = IPMarket(market).swapSyForExactPt(receiver, ptFromSwap, EMPTY_BYTES);

        netPtOut = ptFromBurn + ptFromSwap;

        // fail-safe
        if (netPtOut < minPtOut) assert(false);

        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, netLpToRemove, netPtOut);
    }

    function removeLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        // transfer LP to market
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        // burn LP, SY sent to receiver
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

        // transfer LP to market, burn LP, SY sent to either SY or bulk
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        uint256 netSyReceived;

        (netSyReceived, netSyFee) = _removeLiquiditySingleSy(
            _syOrBulk(address(SY), output),
            market,
            netLpToRemove,
            1
        );

        // redeem SY to token
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

        // calculate the PT amount needed to add liquidity
        (uint256 netPtFromSwap, , ) = state.approxSwapSyToAddLiquidity(
            YT.newIndex(),
            netSyIn,
            block.timestamp,
            guessPtReceivedFromSy
        );

        // execute the swap & the addLiquidity
        uint256 netSySwapped;
        (netSySwapped, netSyFee) = IPMarket(market).swapSyForExactPt(
            market,
            netPtFromSwap,
            EMPTY_BYTES
        );

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyIn - netSySwapped, netPtFromSwap);

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
