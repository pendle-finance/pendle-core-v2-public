// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPRouterStatic.sol";
import "./StorageLayout.sol";

contract ActionMarketCoreStatic is StorageLayout, IPActionMarketCoreStatic {
    using PMath for uint256;
    using PMath for int256;

    using LogExpMath for int256;
    using PYIndexLib for PYIndex;
    using PYIndexLib for IPYieldToken;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using MarketMathCore for MarketState;

    // ============ ADD REMOVE LIQUIDITY ============

    function addLiquidityDualSyAndPtStatic(
        address market,
        uint256 netSyDesired,
        uint256 netPtDesired
    ) public view returns (uint256 netLpOut, uint256 netSyUsed, uint256 netPtUsed) {
        MarketState memory state = _readState(market);
        (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(netSyDesired, netPtDesired, block.timestamp);
    }

    function addLiquidityDualTokenAndPtStatic(
        address market,
        address tokenIn,
        uint256 netTokenDesired,
        uint256 netPtDesired
    )
        public
        view
        returns (
            uint256 netLpOut,
            uint256 netTokenUsed,
            uint256 netPtUsed,
            // extra-info
            uint256 netSyUsed,
            uint256 netSyDesired
        )
    {
        netSyDesired = _mintSyFromTokenStatic(market, tokenIn, netTokenDesired);

        (netLpOut, netSyUsed, netPtUsed) = addLiquidityDualSyAndPtStatic(market, netSyDesired, netPtDesired);

        if (netSyUsed != netSyDesired) revert Errors.RouterNotAllSyUsed(netSyDesired, netSyUsed);

        netTokenUsed = netTokenDesired;
    }

    /// @dev netPtToSwap is the parameter to approx
    function addLiquiditySinglePtStatic(
        address market,
        uint256 netPtIn
    )
        public
        view
        returns (
            uint256 netLpOut,
            uint256 netPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyFromSwap
        )
    {
        MarketState memory state = _readState(market);

        (netPtToSwap, , ) = state.approxSwapPtToAddLiquidity(
            _pyIndex(market),
            netPtIn,
            0,
            block.timestamp,
            defaultApproxParams
        );

        state = _readState(market); // re-read

        (netSyFromSwap, netSyFee, ) = state.swapExactPtForSy(_pyIndex(market), netPtToSwap, block.timestamp);
        (, netLpOut, , ) = state.addLiquidity(netSyFromSwap, netPtIn - netPtToSwap, block.timestamp);

        priceImpact = _calcPriceImpactPt(market, netPtToSwap.neg());
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netPtFromSwap is the parameter to approx
    function addLiquiditySingleSyStatic(
        address market,
        uint256 netSyIn
    )
        public
        view
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyToSwap
        )
    {
        MarketState memory state = _readState(market);

        (netPtFromSwap, , ) = state.approxSwapSyToAddLiquidity(
            _pyIndex(market),
            netSyIn,
            0,
            block.timestamp,
            defaultApproxParams
        );

        state = _readState(market); // re-read

        (netSyToSwap, netSyFee, ) = state.swapSyForExactPt(_pyIndex(market), netPtFromSwap, block.timestamp);
        (, netLpOut, , ) = state.addLiquidity(netSyIn - netSyToSwap, netPtFromSwap, block.timestamp);

        priceImpact = _calcPriceImpactPt(market, netPtFromSwap.Int());
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function addLiquiditySingleTokenStatic(
        address market,
        address tokenIn,
        uint256 netTokenIn
    )
        public
        view
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyMinted,
            uint256 netSyToSwap
        )
    {
        netSyMinted = _mintSyFromTokenStatic(market, tokenIn, netTokenIn);
        (netLpOut, netPtFromSwap, netSyFee, priceImpact, exchangeRateAfter, netSyToSwap) = addLiquiditySingleSyStatic(
            market,
            netSyMinted
        );
    }

    function addLiquiditySingleTokenKeepYtStatic(
        address market,
        address tokenIn,
        uint256 netTokenIn
    )
        public
        view
        returns (
            uint256 netLpOut,
            uint256 netYtOut,
            // extra-info
            uint256 netSyMinted,
            uint256 netSyToPY
        )
    {
        netSyMinted = _mintSyFromTokenStatic(market, tokenIn, netTokenIn);
        (netLpOut, netYtOut, netSyToPY) = addLiquiditySingleSyKeepYtStatic(market, netSyMinted);
    }

    function addLiquiditySingleSyKeepYtStatic(
        address market,
        uint256 netSyIn
    )
        public
        view
        returns (
            uint256 netLpOut,
            uint256 netYtOut,
            // extra-info
            uint256 netSyToPY
        )
    {
        MarketState memory state = _readState(market);
        PYIndex index = _pyIndex(market);

        netSyToPY = (netSyIn * state.totalPt.Uint()) / (state.totalPt.Uint() + index.syToAsset(state.totalSy.Uint()));

        netYtOut = index.syToAsset(netSyToPY);

        (, netLpOut, , ) = state.addLiquidity(netSyIn - netSyToPY, netYtOut, block.timestamp);
    }

    function removeLiquidityDualSyAndPtStatic(
        address market,
        uint256 netLpToRemove
    ) public view returns (uint256 netSyOut, uint256 netPtOut) {
        MarketState memory state = _readState(market);
        (netSyOut, netPtOut) = state.removeLiquidity(netLpToRemove);
    }

    function removeLiquidityDualTokenAndPtStatic(
        address market,
        uint256 netLpToRemove,
        address tokenOut
    ) public view returns (uint256 netTokenOut, uint256 netPtOut, uint256 netSyToRedeem) {
        (netSyToRedeem, netPtOut) = removeLiquidityDualSyAndPtStatic(market, netLpToRemove);
        netTokenOut = _redeemSyToTokenStatic(market, tokenOut, netSyToRedeem);
    }

    /// @dev netPtFromSwap is the parameter to approx
    /// @notice should revert post-expiry
    function removeLiquiditySinglePtStatic(
        address market,
        uint256 netLpToRemove
    )
        public
        view
        returns (
            uint256 netPtOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyFromBurn,
            uint256 netPtFromBurn
        )
    {
        MarketState memory state = _readState(market);

        (netSyFromBurn, netPtFromBurn) = state.removeLiquidity(netLpToRemove);
        (netPtFromSwap, netSyFee) = state.approxSwapExactSyForPt(
            _pyIndex(market),
            netSyFromBurn,
            block.timestamp,
            defaultApproxParams
        );

        netPtOut = netPtFromBurn + netPtFromSwap;
        priceImpact = _calcPriceImpactPt(market, netPtFromSwap.Int());

        // Execute swap to calculate exchangeRateAfter
        state.swapSyForExactPt(_pyIndex(market), netPtFromSwap, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function removeLiquiditySingleSyStatic(
        address market,
        uint256 netLpToRemove
    )
        public
        view
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyFromBurn,
            uint256 netPtFromBurn,
            uint256 netSyFromSwap
        )
    {
        MarketState memory state = _readState(market);

        (netSyFromBurn, netPtFromBurn) = state.removeLiquidity(netLpToRemove);

        if (IPMarket(market).isExpired()) {
            netSyOut = netSyFromBurn + _pyIndex(market).assetToSy(netPtFromBurn);
            netSyFee = 0;
            priceImpact = 0;
            exchangeRateAfter = PMath.ONE;
        } else {
            (netSyFromSwap, netSyFee, ) = state.swapExactPtForSy(_pyIndex(market), netPtFromBurn, block.timestamp);

            netSyOut = netSyFromBurn + netSyFromSwap;
            priceImpact = _calcPriceImpactPt(market, netPtFromBurn.neg());
            exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
        }
    }

    function removeLiquiditySingleTokenStatic(
        address market,
        uint256 netLpToRemove,
        address tokenOut
    )
        public
        view
        returns (
            uint256 netTokenOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyOut,
            uint256 netSyFromBurn,
            uint256 netPtFromBurn,
            uint256 netSyFromSwap
        )
    {
        (
            netSyOut,
            netSyFee,
            priceImpact,
            exchangeRateAfter,
            netSyFromBurn,
            netPtFromBurn,
            netSyFromSwap
        ) = removeLiquiditySingleSyStatic(market, netLpToRemove);

        netTokenOut = _redeemSyToTokenStatic(market, tokenOut, netSyOut);
    }

    // ============ SWAP PT ============

    function swapExactPtForSyStatic(
        address market,
        uint256 exactPtIn
    ) public view returns (uint256 netSyOut, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter) {
        MarketState memory state = _readState(market);
        (netSyOut, netSyFee, ) = state.swapExactPtForSy(_pyIndex(market), exactPtIn, block.timestamp);
        priceImpact = _calcPriceImpactPt(market, exactPtIn.neg());
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function swapSyForExactPtStatic(
        address market,
        uint256 exactPtOut
    ) public view returns (uint256 netSyIn, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter) {
        MarketState memory state = _readState(market);
        (netSyIn, netSyFee, ) = state.swapSyForExactPt(_pyIndex(market), exactPtOut, block.timestamp);
        priceImpact = _calcPriceImpactPt(market, exactPtOut.Int());
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netPtOut is the parameter to approx
    function swapExactSyForPtStatic(
        address market,
        uint256 exactSyIn
    ) public view returns (uint256 netPtOut, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter) {
        MarketState memory state = _readState(market);
        (netPtOut, netSyFee) = state.approxSwapExactSyForPt(
            _pyIndex(market),
            exactSyIn,
            block.timestamp,
            defaultApproxParams
        );
        priceImpact = _calcPriceImpactPt(market, netPtOut.Int());

        // Execute swap to calculate exchangeRateAfter
        state.swapSyForExactPt(_pyIndex(market), netPtOut, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netPtIn is the parameter to approx
    function swapPtForExactSyStatic(
        address market,
        uint256 exactSyOut
    ) public view returns (uint256 netPtIn, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter) {
        MarketState memory state = _readState(market);

        (netPtIn, , netSyFee) = state.approxSwapPtForExactSy(
            _pyIndex(market),
            exactSyOut,
            block.timestamp,
            defaultApproxParams
        );
        priceImpact = _calcPriceImpactPt(market, netPtIn.neg());

        // Execute swap to calculate exchangeRateAfter
        state.swapExactPtForSy(_pyIndex(market), netPtIn, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function swapExactTokenForPtStatic(
        address market,
        address tokenIn,
        uint256 amountTokenIn
    )
        public
        view
        returns (
            uint256 netPtOut,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        netSyMinted = _mintSyFromTokenStatic(market, tokenIn, amountTokenIn);

        (netPtOut, netSyFee, priceImpact, exchangeRateAfter) = swapExactSyForPtStatic(market, netSyMinted);
    }

    function swapExactPtForTokenStatic(
        address market,
        uint256 exactPtIn,
        address tokenOut
    )
        public
        view
        returns (
            uint256 netTokenOut,
            uint256 netSyToRedeem,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        (netSyToRedeem, netSyFee, priceImpact, exchangeRateAfter) = swapExactPtForSyStatic(market, exactPtIn);

        netTokenOut = _redeemSyToTokenStatic(market, tokenOut, netSyToRedeem);
    }

    // ============ SWAP YT ============

    function swapSyForExactYtStatic(
        address market,
        uint256 exactYtOut
    )
        public
        view
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyReceivedInt,
            uint256 totalSyNeedInt
        )
    {
        priceImpact = _calcPriceImpactYt(market, exactYtOut.neg());

        MarketState memory state = _readState(market);
        PYIndex index = _pyIndex(market);

        (netSyReceivedInt, netSyFee, ) = state.swapExactPtForSy(_pyIndex(market), exactYtOut, block.timestamp);

        totalSyNeedInt = index.assetToSyUp(exactYtOut);
        netSyIn = totalSyNeedInt.subMax0(netSyReceivedInt);

        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netYtOut is the parameter to approx
    function swapExactSyForYtStatic(
        address market,
        uint256 exactSyIn
    ) public view returns (uint256 netYtOut, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter) {
        MarketState memory state = _readState(market);
        PYIndex index = _pyIndex(market);

        (netYtOut, netSyFee) = state.approxSwapExactSyForYt(index, exactSyIn, block.timestamp, defaultApproxParams);

        priceImpact = _calcPriceImpactYt(market, netYtOut.neg());

        // Execute swap to calculate exchangeRateAfter
        state.swapExactPtForSy(index, netYtOut, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function swapExactYtForSyStatic(
        address market,
        uint256 exactYtIn
    )
        public
        view
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyOwedInt,
            uint256 netPYToRepaySyOwedInt,
            uint256 netPYToRedeemSyOutInt
        )
    {
        priceImpact = _calcPriceImpactYt(market, exactYtIn.Int());

        MarketState memory state = _readState(market);

        PYIndex index = _pyIndex(market);

        (netSyOwedInt, netSyFee, ) = state.swapSyForExactPt(index, exactYtIn, block.timestamp);

        netPYToRepaySyOwedInt = index.syToAssetUp(netSyOwedInt);
        netPYToRedeemSyOutInt = exactYtIn - netPYToRepaySyOwedInt;

        netSyOut = index.assetToSy(netPYToRedeemSyOutInt);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function swapExactYtForTokenStatic(
        address market,
        uint256 exactYtIn,
        address tokenOut
    )
        public
        view
        returns (
            uint256 netTokenOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            // extra-info
            uint256 netSyOut,
            uint256 netSyOwedInt,
            uint256 netPYToRepaySyOwedInt,
            uint256 netPYToRedeemSyOutInt
        )
    {
        (
            netSyOut,
            netSyFee,
            priceImpact,
            exchangeRateAfter,
            netSyOwedInt,
            netPYToRepaySyOwedInt,
            netPYToRedeemSyOutInt
        ) = swapExactYtForSyStatic(market, exactYtIn);

        netTokenOut = _redeemSyToTokenStatic(market, tokenOut, netSyOut);
    }

    /// @dev netYtIn is the parameter to approx
    function swapYtForExactSyStatic(
        address market,
        uint256 exactSyOut
    ) public view returns (uint256 netYtIn, uint256 netSyFee, uint256 priceImpact, uint256 exchangeRateAfter) {
        MarketState memory state = _readState(market);

        PYIndex index = _pyIndex(market);

        (netYtIn, , netSyFee) = state.approxSwapYtForExactSy(index, exactSyOut, block.timestamp, defaultApproxParams);
        priceImpact = _calcPriceImpactYt(market, netYtIn.Int());

        // Execute swap to calculate exchangeRateAfter
        state.swapSyForExactPt(index, netYtIn, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function swapExactTokenForYtStatic(
        address market,
        address tokenIn,
        uint256 amountTokenIn
    )
        public
        view
        returns (
            uint256 netYtOut,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        netSyMinted = _mintSyFromTokenStatic(market, tokenIn, amountTokenIn);
        (netYtOut, netSyFee, priceImpact, exchangeRateAfter) = swapExactSyForYtStatic(market, netSyMinted);
    }

    // totalPtToSwap is the param to approx
    function swapExactPtForYtStatic(
        address market,
        uint256 exactPtIn
    )
        public
        view
        returns (
            uint256 netYtOut,
            uint256 totalPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = _readState(market);
        PYIndex index = _pyIndex(market);

        (netYtOut, totalPtToSwap, netSyFee) = state.approxSwapExactPtForYt(
            index,
            exactPtIn,
            block.timestamp,
            defaultApproxParams
        );
        priceImpact = _calcPriceImpactPY(market, totalPtToSwap.neg());

        // Execute swap to calculate exchangeRateAfter
        state.swapExactPtForSy(index, totalPtToSwap, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    // totalPtSwapped is the param to approx
    function swapExactYtForPtStatic(
        address market,
        uint256 exactYtIn
    )
        public
        view
        returns (
            uint256 netPtOut,
            uint256 totalPtSwapped,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = _readState(market);
        PYIndex index = _pyIndex(market);

        (netPtOut, totalPtSwapped, netSyFee) = state.approxSwapExactYtForPt(
            index,
            exactYtIn,
            block.timestamp,
            defaultApproxParams
        );

        priceImpact = _calcPriceImpactPY(market, totalPtSwapped.Int());

        // Execute swap to calculate exchangeRateAfter
        state.swapSyForExactPt(index, totalPtSwapped, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function _calcPriceImpactPY(address market, int256 netPtOut) internal view returns (uint256) {
        return IPRouterStatic(address(this)).calcPriceImpactPY(market, netPtOut);
    }

    function _calcPriceImpactPt(address market, int256 netPtOut) internal view returns (uint256) {
        return IPRouterStatic(address(this)).calcPriceImpactPt(market, netPtOut);
    }

    function _calcPriceImpactYt(address market, int256 netPtOut) internal view returns (uint256) {
        return IPRouterStatic(address(this)).calcPriceImpactYt(market, netPtOut);
    }

    function _mintSyFromTokenStatic(
        address market,
        address tokenIn,
        uint256 netTokenToDeposit
    ) internal view returns (uint256) {
        return IPRouterStatic(address(this)).mintSyFromTokenStatic(_getSyMarket(market), tokenIn, netTokenToDeposit);
    }

    function _redeemSyToTokenStatic(
        address market,
        address tokenOut,
        uint256 netSyToRedeem
    ) internal view returns (uint256) {
        return IPRouterStatic(address(this)).redeemSyToTokenStatic(_getSyMarket(market), tokenOut, netSyToRedeem);
    }

    function _getTradeExchangeRateExcludeFee(address market, MarketState memory state) internal view returns (uint256) {
        return IPRouterStatic(address(this)).getTradeExchangeRateExcludeFee(market, state);
    }

    function _readState(address market) internal view returns (MarketState memory) {
        return IPMarket(market).readState(address(this));
    }

    function _pyIndex(address market) private view returns (PYIndex) {
        return PYIndex.wrap(IPRouterStatic(address(this)).pyIndexCurrentViewMarket(market));
    }

    function _getSyMarket(address market) internal view returns (address) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        return address(SY);
    }
}
