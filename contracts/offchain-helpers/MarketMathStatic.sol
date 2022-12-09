// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../router/base/MarketApproxLib.sol";
import "../interfaces/IPMarket.sol";

library MarketMathStatic {
    using MarketMathCore for MarketState;
    using MarketApproxPtInLib for MarketState;
    using MarketApproxPtOutLib for MarketState;
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;
    using PYIndexLib for PYIndex;
    using PYIndexLib for IPYieldToken;

    function getDefaultApproxParams() public pure returns (ApproxParams memory) {
        return
            ApproxParams({
                guessMin: 0,
                guessMax: type(uint256).max,
                guessOffchain: 0,
                maxIteration: 256,
                eps: 1e14
            });
    }

    function addLiquidityDualSyAndPtStatic(
        address market,
        uint256 netSyDesired,
        uint256 netPtDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netSyUsed,
            uint256 netPtUsed
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));
        (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(
            netSyDesired,
            netPtDesired,
            block.timestamp
        );
    }

    /// @dev netPtToSwap is the parameter to approx
    function addLiquiditySinglePtStatic(address market, uint256 netPtIn)
        external
        returns (
            uint256 netLpOut,
            uint256 netPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));

        (netPtToSwap, , ) = state.approxSwapPtToAddLiquidity(
            pyIndex(market),
            netPtIn,
            block.timestamp,
            getDefaultApproxParams()
        );

        state = IPMarket(market).readState(address(this)); // re-read

        uint256 netSyReceived;
        (netSyReceived, netSyFee, ) = state.swapExactPtForSy(
            pyIndex(market),
            netPtToSwap,
            block.timestamp
        );
        (, netLpOut, , ) = state.addLiquidity(
            netSyReceived,
            netPtIn - netPtToSwap,
            block.timestamp
        );

        priceImpact = calcPriceImpactPt(market, netPtToSwap.neg());
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netPtFromSwap is the parameter to approx
    function addLiquiditySingleSyStatic(address market, uint256 netSyIn)
        public
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));

        (netPtFromSwap, , ) = state.approxSwapSyToAddLiquidity(
            pyIndex(market),
            netSyIn,
            block.timestamp,
            getDefaultApproxParams()
        );

        state = IPMarket(market).readState(address(this)); // re-read

        uint256 netSySwap;
        (netSySwap, netSyFee, ) = state.swapSyForExactPt(
            pyIndex(market),
            netPtFromSwap,
            block.timestamp
        );
        (, netLpOut, , ) = state.addLiquidity(netSyIn - netSySwap, netPtFromSwap, block.timestamp);

        priceImpact = calcPriceImpactPt(market, netPtFromSwap.Int());
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function removeLiquidityDualSyAndPtStatic(address market, uint256 netLpToRemove)
        external
        view
        returns (uint256 netSyOut, uint256 netPtOut)
    {
        MarketState memory state = IPMarket(market).readState(address(this));
        (netSyOut, netPtOut) = state.removeLiquidity(netLpToRemove);
    }

    /// @dev netPtFromSwap is the parameter to approx
    function removeLiquiditySinglePtStatic(address market, uint256 netLpToRemove)
        external
        returns (
            uint256 netPtOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));

        (uint256 syFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);
        (netPtFromSwap, netSyFee) = state.approxSwapExactSyForPt(
            pyIndex(market),
            syFromBurn,
            block.timestamp,
            getDefaultApproxParams()
        );

        netPtOut = ptFromBurn + netPtFromSwap;
        priceImpact = calcPriceImpactPt(market, netPtFromSwap.Int());

        // Execute swap to calculate exchangeRateAfter
        state.swapSyForExactPt(pyIndex(market), netPtFromSwap, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function removeLiquiditySingleSyStatic(address market, uint256 netLpToRemove)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));

        (uint256 syFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);

        if (IPMarket(market).isExpired()) {
            netSyOut = syFromBurn + pyIndex(market).assetToSy(ptFromBurn);
        } else {
            uint256 syFromSwap;
            (syFromSwap, netSyFee, ) = state.swapExactPtForSy(
                pyIndex(market),
                ptFromBurn,
                block.timestamp
            );

            netSyOut = syFromBurn + syFromSwap;
            priceImpact = calcPriceImpactPt(market, ptFromBurn.neg());
            exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
        }
    }

    function swapExactPtForSyStatic(address market, uint256 exactPtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));
        (netSyOut, netSyFee, ) = state.swapExactPtForSy(
            pyIndex(market),
            exactPtIn,
            block.timestamp
        );
        priceImpact = calcPriceImpactPt(market, exactPtIn.neg());
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function swapSyForExactPtStatic(address market, uint256 exactPtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));
        (netSyIn, netSyFee, ) = state.swapSyForExactPt(
            pyIndex(market),
            exactPtOut,
            block.timestamp
        );
        priceImpact = calcPriceImpactPt(market, exactPtOut.Int());
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netPtOut is the parameter to approx
    function swapExactSyForPtStatic(address market, uint256 exactSyIn)
        public
        returns (
            uint256 netPtOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));
        (netPtOut, netSyFee) = state.approxSwapExactSyForPt(
            pyIndex(market),
            exactSyIn,
            block.timestamp,
            getDefaultApproxParams()
        );
        priceImpact = calcPriceImpactPt(market, netPtOut.Int());

        // Execute swap to calculate exchangeRateAfter
        state.swapSyForExactPt(pyIndex(market), netPtOut, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netPtIn is the parameter to approx
    function swapPtForExactSyStatic(address market, uint256 exactSyOut)
        public
        returns (
            uint256 netPtIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));

        (netPtIn, , netSyFee) = state.approxSwapPtForExactSy(
            pyIndex(market),
            exactSyOut,
            block.timestamp,
            getDefaultApproxParams()
        );
        priceImpact = calcPriceImpactPt(market, netPtIn.neg());

        // Execute swap to calculate exchangeRateAfter
        state.swapExactPtForSy(pyIndex(market), netPtIn, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function swapSyForExactYtStatic(address market, uint256 exactYtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        priceImpact = calcPriceImpactYt(market, exactYtOut.neg());

        MarketState memory state = IPMarket(market).readState(address(this));
        PYIndex index = pyIndex(market);

        uint256 syReceived;
        (syReceived, netSyFee, ) = state.swapExactPtForSy(
            pyIndex(market),
            exactYtOut,
            block.timestamp
        );

        uint256 totalSyNeed = index.assetToSyUp(exactYtOut);
        netSyIn = totalSyNeed.subMax0(syReceived);

        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netYtOut is the parameter to approx
    function swapExactSyForYtStatic(address market, uint256 exactSyIn)
        public
        returns (
            uint256 netYtOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));
        PYIndex index = pyIndex(market);

        (netYtOut, netSyFee) = state.approxSwapExactSyForYt(
            index,
            exactSyIn,
            block.timestamp,
            getDefaultApproxParams()
        );

        priceImpact = calcPriceImpactYt(market, netYtOut.neg());

        // Execute swap to calculate exchangeRateAfter
        state.swapExactPtForSy(index, netYtOut, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function swapExactYtForSyStatic(address market, uint256 exactYtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        priceImpact = calcPriceImpactYt(market, exactYtIn.Int());

        MarketState memory state = IPMarket(market).readState(address(this));

        PYIndex index = pyIndex(market);

        uint256 syOwed;
        (syOwed, netSyFee, ) = state.swapSyForExactPt(index, exactYtIn, block.timestamp);

        uint256 amountPYToRepaySyOwed = index.syToAssetUp(syOwed);
        uint256 amountPYToRedeemSyOut = exactYtIn - amountPYToRepaySyOwed;

        netSyOut = index.assetToSy(amountPYToRedeemSyOut);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    /// @dev netYtIn is the parameter to approx
    function swapYtForExactSyStatic(address market, uint256 exactSyOut)
        external
        returns (
            uint256 netYtIn,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));

        PYIndex index = pyIndex(market);

        (netYtIn, , netSyFee) = state.approxSwapYtForExactSy(
            index,
            exactSyOut,
            block.timestamp,
            getDefaultApproxParams()
        );
        priceImpact = calcPriceImpactYt(market, netYtIn.Int());

        // Execute swap to calculate exchangeRateAfter
        state.swapSyForExactPt(index, netYtIn, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    // totalPtToSwap is the param to approx
    function swapExactPtForYt(address market, uint256 exactPtIn)
        external
        returns (
            uint256 netYtOut,
            uint256 totalPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));
        PYIndex index = pyIndex(market);

        (netYtOut, totalPtToSwap, netSyFee) = state.approxSwapExactPtForYt(
            index,
            exactPtIn,
            block.timestamp,
            getDefaultApproxParams()
        );
        priceImpact = calcPriceImpactPY(market, totalPtToSwap.neg());

        // Execute swap to calculate exchangeRateAfter
        state.swapExactPtForSy(index, totalPtToSwap, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    // totalPtSwapped is the param to approx
    function swapExactYtForPt(address market, uint256 exactYtIn)
        external
        returns (
            uint256 netPtOut,
            uint256 totalPtSwapped,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter
        )
    {
        MarketState memory state = IPMarket(market).readState(address(this));
        PYIndex index = pyIndex(market);

        (netPtOut, totalPtSwapped, netSyFee) = state.approxSwapExactYtForPt(
            index,
            exactYtIn,
            block.timestamp,
            getDefaultApproxParams()
        );

        priceImpact = calcPriceImpactPY(market, totalPtSwapped.Int());

        // Execute swap to calculate exchangeRateAfter
        state.swapSyForExactPt(index, totalPtSwapped, block.timestamp);
        exchangeRateAfter = _getTradeExchangeRateExcludeFee(market, state);
    }

    function pyIndex(address market) public returns (PYIndex index) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        return YT.newIndex();
    }

    function getTradeExchangeRateExcludeFee(address market) public returns (uint256) {
        if (IPMarket(market).isExpired()) return Math.ONE;
        MarketState memory state = IPMarket(market).readState(address(this));
        return _getTradeExchangeRateExcludeFee(market, state);
    }

    function _getTradeExchangeRateExcludeFee(address market, MarketState memory state)
        public
        returns (uint256)
    {
        MarketPreCompute memory comp = state.getMarketPreCompute(pyIndex(market), block.timestamp);
        int256 preFeeExchangeRate = MarketMathCore._getExchangeRate(
            state.totalPt,
            comp.totalAsset,
            comp.rateScalar,
            comp.rateAnchor,
            0
        );
        return preFeeExchangeRate.Uint();
    }

    function getTradeExchangeRateIncludeFee(address market, int256 netPtOut)
        public
        returns (uint256)
    {
        if (IPMarket(market).isExpired()) return Math.ONE;
        int256 netPtToAccount = netPtOut;
        MarketState memory state = IPMarket(market).readState(address(this));
        MarketPreCompute memory comp = state.getMarketPreCompute(pyIndex(market), block.timestamp);

        int256 preFeeExchangeRate = MarketMathCore._getExchangeRate(
            state.totalPt,
            comp.totalAsset,
            comp.rateScalar,
            comp.rateAnchor,
            netPtToAccount
        );

        if (netPtToAccount > 0) {
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(comp.feeRate);
            if (postFeeExchangeRate < Math.IONE)
                revert Errors.MarketExchangeRateBelowOne(postFeeExchangeRate);
            return postFeeExchangeRate.Uint();
        } else {
            return preFeeExchangeRate.mulDown(comp.feeRate).Uint();
        }
    }

    function calcPriceImpactPt(address market, int256 netPtOut)
        public
        returns (uint256 priceImpact)
    {
        uint256 preTradeRate = getTradeExchangeRateIncludeFee(market, _getSign(netPtOut));
        uint256 tradedRate = getTradeExchangeRateIncludeFee(market, netPtOut);
        priceImpact = _calculateImpact(preTradeRate, tradedRate);
    }

    function calcPriceImpactYt(address market, int256 netPtOut)
        public
        returns (uint256 priceImpact)
    {
        uint256 ytPreTradeRate = _calcVirtualYTPrice(
            getTradeExchangeRateIncludeFee(market, _getSign(netPtOut))
        );
        uint256 ytTradedRate = _calcVirtualYTPrice(
            getTradeExchangeRateIncludeFee(market, netPtOut)
        );
        priceImpact = _calculateImpact(ytPreTradeRate, ytTradedRate);
    }

    function calcPriceImpactPY(address market, int256 netPtOut)
        public
        returns (uint256 priceImpact)
    {
        uint256 ptPreTradeRate = getTradeExchangeRateIncludeFee(market, _getSign(netPtOut));
        uint256 ytPreTradeRate = _calcVirtualYTPrice(ptPreTradeRate);
        uint256 ptTradeRate = getTradeExchangeRateIncludeFee(market, netPtOut);
        uint256 ytTradeRate = _calcVirtualYTPrice(ptTradeRate);

        uint256 pyPreTradeRate = ytPreTradeRate.divDown(ptPreTradeRate);
        uint256 pyTradeRate = ytTradeRate.divDown(ptTradeRate);
        priceImpact = _calculateImpact(pyPreTradeRate, pyTradeRate);
    }

    function getPtImpliedYield(address market) public view returns (int256) {
        MarketState memory state = IPMarket(market).readState(address(this));

        int256 lnImpliedRate = (state.lastLnImpliedRate).Int();
        return lnImpliedRate.exp();
    }

    function _calcVirtualYTPrice(uint256 ptAssetExchangeRate)
        private
        pure
        returns (uint256 ytAssetExchangeRate)
    {
        // 1 asset = EX pt
        // 1 pt = 1/EX Asset
        // 1 yt + 1/EX Asset = 1 Asset
        // 1 yt = 1 Asset - 1/EX Asset
        // 1 yt = (EX - 1) / EX Asset
        return (ptAssetExchangeRate - Math.ONE).divDown(ptAssetExchangeRate);
    }

    function _getSign(int256 netPtOut) private pure returns (int256) {
        return netPtOut > 0 ? int256(1) : int256(-1);
    }

    function _calculateImpact(uint256 rateBefore, uint256 rateTraded)
        private
        pure
        returns (uint256 impact)
    {
        impact = (rateBefore.Int() - rateTraded.Int()).abs().divDown(rateBefore);
    }
}
