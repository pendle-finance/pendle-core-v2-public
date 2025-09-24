// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./base/ActionBase.sol";
import "../interfaces/IPActionAddRemoveLiqV3.sol";

import {ActionDelegateBase} from "./base/ActionDelegateBase.sol";

contract ActionAddRemoveLiqV3 is IPActionAddRemoveLiqV3, ActionBase, ActionDelegateBase {
    using PMath for uint256;
    using PMath for int256;
    using MarketMathCore for MarketState;
    using MarketApproxPtInLibV2 for MarketState;
    using MarketApproxPtOutLibV2 for MarketState;
    using PYIndexLib for IPYieldToken;
    using PYIndexLib for PYIndex;

    // ------------------ ADD LIQUIDITY DUAL ------------------

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function addLiquidityDualTokenAndPt(
        address receiver,
        address market,
        TokenInput calldata input,
        uint256 netPtDesired,
        uint256 minLpOut
    ) external payable returns (uint256 netLpOut, uint256 netPtUsed, uint256 netSyInterm) {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        netSyInterm = _mintSyFromToken(market, address(SY), 1, input);
        uint256 netSyUsed;

        (, , netSyUsed, netPtUsed) = _readMarket(market).addLiquidity(netSyInterm, netPtDesired, block.timestamp);

        if (netSyInterm != netSyUsed) {
            revert("Slippage: NOT_ALL_SY_USED");
        }

        // SY has been minted and transferred to the market
        _transferFrom(PT, msg.sender, market, netPtUsed);
        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyUsed, netPtUsed);

        if (netLpOut < minLpOut) revert("Slippage: INSUFFICIENT_LP_OUT");

        emit AddLiquidityDualTokenAndPt(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            input.netTokenIn,
            netPtUsed,
            netLpOut,
            netSyInterm
        );
    }

    function addLiquidityDualSyAndPt(
        address receiver,
        address market,
        uint256 netSyDesired,
        uint256 netPtDesired,
        uint256 minLpOut
    ) external returns (uint256 netLpOut, uint256 netSyUsed, uint256 netPtUsed) {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        // calculate the amount of SY and PT to be used
        (, netLpOut, netSyUsed, netPtUsed) = _readMarket(market).addLiquidity(
            netSyDesired,
            netPtDesired,
            block.timestamp
        );

        _transferFrom(SY, msg.sender, market, netSyUsed);
        _transferFrom(PT, msg.sender, market, netPtUsed);
        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyUsed, netPtUsed);

        if (netLpOut < minLpOut) revert("Slippage: INSUFFICIENT_LP_OUT");

        emit AddLiquidityDualSyAndPt(msg.sender, market, receiver, netSyUsed, netPtUsed, netLpOut);
    }

    // ------------------ ADD LIQUIDITY SINGLE PT ------------------

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function addLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netPtIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtSwapToSy,
        LimitOrderData calldata limit
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        if (canUseOnchainApproximation(guessPtSwapToSy, limit)) {
            return delegateToAddLiquiditySinglePtSimple(receiver, market, netPtIn, minLpOut);
        }
        (, IPPrincipalToken PT, IPYieldToken YT) = IPMarket(market).readTokens();
        _transferFrom(PT, msg.sender, _entry_addLiquiditySinglePt(market, limit), netPtIn);

        uint256 netPtLeft = netPtIn;
        uint256 netSyReceived;

        if (!_isEmptyLimit(limit)) {
            (netPtLeft, netSyReceived, netSyFee, ) = _fillLimit(market, PT, netPtLeft, limit);
            _transferOut(address(PT), market, netPtLeft);
        }

        (uint256 netPtSwapMarket, , ) = _readMarket(market).approxSwapPtToAddLiquidityV2(
            YT.newIndex(),
            netPtLeft,
            netSyReceived,
            block.timestamp,
            guessPtSwapToSy
        );

        // execute the swap
        (uint256 netSyOutMarket, uint256 netSyFeeMarket) = IPMarket(market).swapExactPtForSy(
            market,
            netPtSwapMarket,
            EMPTY_BYTES
        );

        netPtLeft -= netPtSwapMarket;
        netSyReceived += netSyOutMarket;
        netSyFee += netSyFeeMarket;

        // execute the addLiquidity
        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyReceived, netPtLeft);

        if (netLpOut < minLpOut) revert("Slippage: INSUFFICIENT_LP_OUT");

        emit AddLiquiditySinglePt(msg.sender, market, receiver, netPtIn, netLpOut);
    }

    // ------------------ ADD LIQUIDITY SINGLE TOKEN ------------------

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy,
        TokenInput calldata input,
        LimitOrderData calldata limit
    ) external payable returns (uint256 netLpOut, uint256 netSyFee, uint256 netSyInterm) {
        if (canUseOnchainApproximation(guessPtReceivedFromSy, limit)) {
            return delegateToAddLiquiditySingleTokenSimple(receiver, market, minLpOut, input);
        }

        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        netSyInterm = _mintSyFromToken(_entry_addLiquiditySingleSy(market, limit), address(SY), 1, input);

        (netLpOut, netSyFee) = _addLiquiditySingleSy(
            receiver,
            market,
            SY,
            YT,
            netSyInterm,
            minLpOut,
            guessPtReceivedFromSy,
            limit
        );

        emit AddLiquiditySingleToken(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            input.netTokenIn,
            netLpOut,
            netSyInterm
        );
    }

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function addLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy,
        LimitOrderData calldata limit
    ) external returns (uint256 netLpOut, uint256 netSyFee) {
        if (canUseOnchainApproximation(guessPtReceivedFromSy, limit)) {
            return delegateToAddLiquiditySingleSySimple(receiver, market, netSyIn, minLpOut);
        }

        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        _transferFrom(SY, msg.sender, _entry_addLiquiditySingleSy(market, limit), netSyIn);

        (netLpOut, netSyFee) = _addLiquiditySingleSy(
            receiver,
            market,
            SY,
            YT,
            netSyIn,
            minLpOut,
            guessPtReceivedFromSy,
            limit
        );

        emit AddLiquiditySingleSy(msg.sender, market, receiver, netSyIn, netLpOut);
    }

    function _addLiquiditySingleSy(
        address receiver,
        address market,
        IStandardizedYield SY,
        IPYieldToken YT,
        uint256 netSyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy,
        LimitOrderData calldata limit
    ) internal returns (uint256 netLpOut, uint256 netSyFee) {
        uint256 netSyLeft = netSyIn;
        uint256 netPtReceived;

        if (!_isEmptyLimit(limit)) {
            (netSyLeft, netPtReceived, netSyFee, ) = _fillLimit(market, SY, netSyLeft, limit);
            _transferOut(address(SY), market, netSyLeft);
        }

        (uint256 netPtOutMarket, , ) = _readMarket(market).approxSwapSyToAddLiquidityV2(
            YT.newIndex(),
            netSyLeft,
            netPtReceived,
            block.timestamp,
            guessPtReceivedFromSy
        );

        (uint256 netSySwapMarket, uint256 netSyFeeMarket) = IPMarket(market).swapSyForExactPt(
            market,
            netPtOutMarket,
            EMPTY_BYTES
        );

        netSyLeft -= netSySwapMarket;
        netPtReceived += netPtOutMarket;
        netSyFee += netSyFeeMarket;

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyLeft, netPtReceived);

        if (netLpOut < minLpOut) revert("Slippage: INSUFFICIENT_LP_OUT");
    }

    // ------------------ ADD LIQUIDITY SINGLE TOKEN KEEP YT ------------------

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function addLiquiditySingleTokenKeepYt(
        address receiver,
        address market,
        uint256 minLpOut,
        uint256 minYtOut,
        TokenInput calldata input
    ) external payable returns (uint256 netLpOut, uint256 netYtOut, uint256 netSyMintPy, uint256 netSyInterm) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        netSyInterm = _mintSyFromToken(address(this), address(SY), 1, input);

        (netLpOut, netYtOut, netSyMintPy) = _addLiquiditySingleSyKeepYt(
            receiver,
            market,
            SY,
            YT,
            netSyInterm,
            minLpOut,
            minYtOut
        );

        emit AddLiquiditySingleTokenKeepYt(
            msg.sender,
            market,
            input.tokenIn,
            receiver,
            input.netTokenIn,
            netLpOut,
            netYtOut,
            netSyMintPy,
            netSyInterm
        );
    }

    function addLiquiditySingleSyKeepYt(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut,
        uint256 minYtOut
    ) external returns (uint256 netLpOut, uint256 netYtOut, uint256 netSyMintPy) {
        (IStandardizedYield SY, , IPYieldToken YT) = IPMarket(market).readTokens();

        _transferIn(address(SY), msg.sender, netSyIn);

        (netLpOut, netYtOut, netSyMintPy) = _addLiquiditySingleSyKeepYt(
            receiver,
            market,
            SY,
            YT,
            netSyIn,
            minLpOut,
            minYtOut
        );

        emit AddLiquiditySingleSyKeepYt(msg.sender, market, receiver, netSyIn, netSyMintPy, netLpOut, netYtOut);
    }

    function _addLiquiditySingleSyKeepYt(
        address receiver,
        address market,
        IStandardizedYield SY,
        IPYieldToken YT,
        uint256 netSyIn,
        uint256 minLpOut,
        uint256 minYtOut
    ) internal returns (uint256 netLpOut, uint256 netYtOut, uint256 netSyMintPy) {
        MarketState memory state = _readMarket(market);

        PYIndex pyIndex = YT.newIndex();

        netSyMintPy =
            (netSyIn * state.totalPt.Uint()) /
            (state.totalPt.Uint() + pyIndex.syToAsset(state.totalSy.Uint()));

        uint256 netSyAddLiquidity = netSyIn - netSyMintPy;

        // transfer SY to mint PY
        _transferOut(address(SY), address(YT), netSyMintPy);

        // the rest of SY goes to market
        _transferOut(address(SY), market, netSyAddLiquidity);

        // PT goes to market, YT goes to receiver
        netYtOut = YT.mintPY(market, receiver);

        (netLpOut, , ) = IPMarket(market).mint(receiver, netSyAddLiquidity, netYtOut);

        if (netLpOut < minLpOut) revert("Slippage: INSUFFICIENT_LP_OUT");
        if (netYtOut < minYtOut) revert("Slippage: INSUFFICIENT_YT_OUT");
    }

    // ------------------ REMOVE LIQUIDITY DUAL ------------------

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function removeLiquidityDualTokenAndPt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output,
        uint256 minPtOut
    ) external returns (uint256 netTokenOut, uint256 netPtOut, uint256 netSyInterm) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();

        // burn LP, SY sent to SY, PT sent to receiver
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        (netSyInterm, netPtOut) = IPMarket(market).burn(address(SY), receiver, netLpToRemove);
        if (netPtOut < minPtOut) revert("Slippage: INSUFFICIENT_PT_OUT");

        // redeem SY to token
        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyInterm, output, false);
        emit RemoveLiquidityDualTokenAndPt(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            netLpToRemove,
            netPtOut,
            netTokenOut,
            netSyInterm
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

        if (netSyOut < minSyOut) revert("Slippage: INSUFFICIENT_SY_OUT");
        if (netPtOut < minPtOut) revert("Slippage: INSUFFICIENT_PT_OUT");

        emit RemoveLiquidityDualSyAndPt(msg.sender, market, receiver, netLpToRemove, netPtOut, netSyOut);
    }

    // ------------------ REMOVE LIQUIDITY SINGLE PT ------------------

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function removeLiquiditySinglePt(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minPtOut,
        ApproxParams calldata guessPtReceivedFromSy,
        LimitOrderData calldata limit
    ) external returns (uint256 netPtOut, uint256 netSyFee) {
        if (canUseOnchainApproximation(guessPtReceivedFromSy, limit)) {
            return delegateToRemoveLiquiditySinglePtSimple(receiver, market, netLpToRemove, minPtOut);
        }

        uint256 netSyLeft;

        // execute the burn
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);
        (uint256 netSyOutBurn, uint256 netPtOutBurn) = IPMarket(market).burn(
            _entry_swapExactSyForPt(market, limit),
            receiver,
            netLpToRemove
        );
        netSyLeft += netSyOutBurn;
        netPtOut += netPtOutBurn;

        (uint256 netPtOutSwap, uint256 netSyFeeSwap) = _swapExactSyForPt(
            receiver,
            market,
            netSyLeft,
            0,
            guessPtReceivedFromSy,
            limit
        );
        netPtOut += netPtOutSwap;
        netSyFee += netSyFeeSwap;

        if (netPtOut < minPtOut) revert("Slippage: INSUFFICIENT_PT_OUT");

        emit RemoveLiquiditySinglePt(msg.sender, market, receiver, netLpToRemove, netPtOut);
    }

    // ------------------ REMOVE LIQUIDITY SINGLE TOKEN ------------------

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function removeLiquiditySingleToken(
        address receiver,
        address market,
        uint256 netLpToRemove,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    ) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();

        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        (netSyInterm, netSyFee) = _removeLiquiditySingleSy(address(SY), market, netLpToRemove, 1, limit);

        netTokenOut = _redeemSyToToken(receiver, address(SY), netSyInterm, output, false);

        emit RemoveLiquiditySingleToken(
            msg.sender,
            market,
            output.tokenOut,
            receiver,
            netLpToRemove,
            netTokenOut,
            netSyInterm
        );
    }

    /// @notice For details on the parameters (input, guessPtSwapToSy, limit, etc.), please refer to IPAllActionTypeV3.
    function removeLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netSyOut, uint256 netSyFee) {
        _transferFrom(IERC20(market), msg.sender, market, netLpToRemove);

        (netSyOut, netSyFee) = _removeLiquiditySingleSy(receiver, market, netLpToRemove, minSyOut, limit);

        emit RemoveLiquiditySingleSy(msg.sender, market, receiver, netLpToRemove, netSyOut);
    }

    // the entry of this will always be market
    function _removeLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        if (IPMarket(market).isExpired()) {
            netSyOut = __removeLpToSyAfterExpiry(receiver, market, netLpToRemove);
        } else {
            (netSyOut, netSyFee) = __removeLpToSyBeforeExpiry(receiver, market, netLpToRemove, limit);
        }
        if (netSyOut < minSyOut) revert("Slippage: INSUFFICIENT_SY_OUT");
    }

    function __removeLpToSyAfterExpiry(
        address receiver,
        address market,
        uint256 netLpToRemove
    ) internal returns (uint256 netSyOut) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();
        (uint256 syFromBurn, ) = IPMarket(market).burn(receiver, address(YT), netLpToRemove);
        netSyOut = syFromBurn + YT.redeemPY(receiver);
    }

    function __removeLpToSyBeforeExpiry(
        address receiver,
        address market,
        uint256 netLpToRemove,
        LimitOrderData calldata limit
    ) internal returns (uint256 netSyOut, uint256 netSyFee) {
        uint256 netPtLeft;

        (uint256 netSyOutBurn, uint256 netPtOutBurn) = IPMarket(market).burn(
            receiver,
            _entry_swapExactPtForSy(market, limit),
            netLpToRemove
        );
        netSyOut += netSyOutBurn;
        netPtLeft += netPtOutBurn;

        (uint256 netSyOutSwap, uint256 netSyFeeSwap) = _swapExactPtForSy(receiver, market, netPtLeft, 0, limit);
        netSyOut += netSyOutSwap;
        netSyFee += netSyFeeSwap;
    }
}
