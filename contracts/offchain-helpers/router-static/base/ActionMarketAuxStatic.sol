// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPRouterStatic.sol";
import "./StorageLayout.sol";
import "hardhat/console.sol";

contract ActionMarketAuxStatic is IPActionMarketAuxStatic {
    using MarketMathCore for MarketState;
    using PMath for int256;
    using PMath for uint256;
    using LogExpMath for int256;
    using PYIndexLib for PYIndex;
    using PYIndexLib for IPYieldToken;

    function getMarketState(
        address market
    )
        public
        view
        returns (
            address pt,
            address yt,
            address sy,
            int256 impliedYield,
            uint256 marketExchangeRateExcludeFee,
            MarketState memory state
        )
    {
        (IStandardizedYield SY, IPPrincipalToken PT, IPYieldToken YT) = _readTokens(market);
        pt = address(PT);
        yt = address(YT);
        sy = address(SY);
        state = _readState(market);
        impliedYield = _getPtImpliedYield(market);
        marketExchangeRateExcludeFee = getTradeExchangeRateExcludeFee(market, state);
    }

    function getTradeExchangeRateExcludeFee(address market, MarketState memory state) public view returns (uint256) {
        if (IPMarket(market).isExpired()) return PMath.ONE;

        MarketPreCompute memory comp = state.getMarketPreCompute(_pyIndex(market), block.timestamp);
        int256 preFeeExchangeRate = MarketMathCore._getExchangeRate(
            state.totalPt,
            comp.totalAsset,
            comp.rateScalar,
            comp.rateAnchor,
            0
        );
        return preFeeExchangeRate.Uint();
    }

    function getTradeExchangeRateIncludeFee(address market, int256 netPtOut) public view returns (uint256) {
        if (IPMarket(market).isExpired()) return PMath.ONE;

        int256 netPtToAccount = netPtOut;
        MarketState memory state = _readState(market);
        MarketPreCompute memory comp = state.getMarketPreCompute(_pyIndex(market), block.timestamp);

        int256 preFeeExchangeRate = MarketMathCore._getExchangeRate(
            state.totalPt,
            comp.totalAsset,
            comp.rateScalar,
            comp.rateAnchor,
            netPtToAccount
        );

        if (netPtToAccount > 0) {
            int256 postFeeExchangeRate = preFeeExchangeRate.divDown(comp.feeRate);
            if (postFeeExchangeRate < PMath.IONE) revert Errors.MarketExchangeRateBelowOne(postFeeExchangeRate);
            return postFeeExchangeRate.Uint();
        } else {
            return preFeeExchangeRate.mulDown(comp.feeRate).Uint();
        }
    }

    function calcPriceImpactPt(address market, int256 netPtOut) public view returns (uint256 priceImpact) {
        uint256 preTradeRate = getTradeExchangeRateIncludeFee(market, _getSign(netPtOut));
        uint256 tradedRate = getTradeExchangeRateIncludeFee(market, netPtOut);
        priceImpact = _calculateImpact(preTradeRate, tradedRate);
    }

    function calcPriceImpactYt(address market, int256 netPtOut) public view returns (uint256 priceImpact) {
        uint256 ytPreTradeRate = _calcVirtualYTPrice(getTradeExchangeRateIncludeFee(market, _getSign(netPtOut)));
        uint256 ytTradedRate = _calcVirtualYTPrice(getTradeExchangeRateIncludeFee(market, netPtOut));
        priceImpact = _calculateImpact(ytPreTradeRate, ytTradedRate);
    }

    function calcPriceImpactPY(address market, int256 netPtOut) public view returns (uint256 priceImpact) {
        uint256 ptPreTradeRate = getTradeExchangeRateIncludeFee(market, _getSign(netPtOut));
        uint256 ptTradeRate = getTradeExchangeRateIncludeFee(market, netPtOut);

        uint256 ptPreTradePrice = PMath.ONE.divDown(ptPreTradeRate);
        uint256 ptTradePrice = PMath.ONE.divDown(ptTradeRate);

        uint256 ytPreTradePrice = _calcVirtualYTPrice(ptPreTradeRate);
        uint256 ytTradePrice = _calcVirtualYTPrice(ptTradeRate);

        uint256 pyPreTradeRate = ytPreTradePrice.divDown(ptPreTradePrice);
        uint256 pyTradeRate = ytTradePrice.divDown(ptTradePrice);
        priceImpact = _calculateImpact(pyPreTradeRate, pyTradeRate);
    }

    /**
     * @notice get the rate of yieldToken & PT
     * @return yieldToken the address of yieldToken
     * @return netPtOut the amount of PT that can be swapped from 1 yieldToken (10**yieldToken.decimals()). If can't swap, return type(uint256).max
     * @return netYieldTokenOut the amount of yieldToken that can be swapped from 1 PT (10**PT.decimals()). If can't swap, return type(uint256).max
     */
    function getYieldTokenAndPtRate(
        address market
    ) public view returns (address yieldToken, uint256 netPtOut, uint256 netYieldTokenOut) {
        (IStandardizedYield SY, IPPrincipalToken PT, ) = _readTokens(market);
        yieldToken = SY.yieldToken();
        uint256 yieldDecimals = IERC20Metadata(yieldToken).decimals();
        uint256 ptDecimals = PT.decimals();

        try IPRouterStatic(address(this)).swapExactTokenForPtStatic(market, yieldToken, 10 ** yieldDecimals) returns (
            uint256 netPtOutRet,
            uint256,
            uint256,
            uint256,
            uint256
        ) {
            netPtOut = netPtOutRet;
        } catch {
            netPtOut = type(uint256).max;
        }

        try IPRouterStatic(address(this)).swapExactPtForTokenStatic(market, 10 ** ptDecimals, yieldToken) returns (
            uint256 netYieldTokenOutRet,
            uint256,
            uint256,
            uint256,
            uint256
        ) {
            netYieldTokenOut = netYieldTokenOutRet;
        } catch {
            netYieldTokenOut = type(uint256).max;
        }
    }

    /**
     * @notice get the rate of yieldToken & YT
     * @return yieldToken the address of yieldToken
     * @return netYtOut the amount of YT that can be swapped from 1 yieldToken (10**yieldToken.decimals()). If can't swap, return type(uint256).max
     * @return netYieldTokenOut the amount of yieldToken that can be swapped from 1 YT (10**YT.decimals()). If can't swap, return type(uint256).max
     */
    function getYieldTokenAndYtRate(
        address market
    ) public view returns (address yieldToken, uint256 netYtOut, uint256 netYieldTokenOut) {
        (IStandardizedYield SY, , IPYieldToken YT) = _readTokens(market);
        yieldToken = SY.yieldToken();
        uint256 yieldDecimals = IERC20Metadata(yieldToken).decimals();
        uint256 ytDecimals = YT.decimals();

        try IPRouterStatic(address(this)).swapExactTokenForYtStatic(market, yieldToken, 10 ** yieldDecimals) returns (
            uint256 netYtOutRet,
            uint256,
            uint256,
            uint256,
            uint256
        ) {
            netYtOut = netYtOutRet;
        } catch {
            netYtOut = type(uint256).max;
        }

        try IPRouterStatic(address(this)).swapExactYtForTokenStatic(market, 10 ** ytDecimals, yieldToken) returns (
            uint256 netYieldTokenOutRet,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        ) {
            netYieldTokenOut = netYieldTokenOutRet;
        } catch {
            netYieldTokenOut = type(uint256).max;
        }
    }

    function getLpToSyRate(address market) public view returns (uint256) {
        (IStandardizedYield SY, , ) = _readTokens(market);
        return getLpToAssetRate(market).divDown(SY.exchangeRate());
    }

    function getPtToSyRate(address market) public view returns (uint256) {
        (IStandardizedYield SY, , ) = _readTokens(market);
        return getPtToAssetRate(market).divDown(SY.exchangeRate());
    }

    function getYtToSyRate(address market) external view returns (uint256) {
        (IStandardizedYield SY, , ) = _readTokens(market);
        return getYtToAssetRate(market).divDown(SY.exchangeRate());
    }

    function getLpToAssetRate(address market) public view returns (uint256) {
        MarketState memory state = _readState(market);
        PYIndex pyIndexCurrent = _pyIndex(market);

        int256 totalHypotheticalAsset;
        if (state.expiry <= block.timestamp) {
            // 1 PT = 1 Asset post-expiry
            totalHypotheticalAsset = state.totalPt + pyIndexCurrent.syToAsset(state.totalSy);
        } else {
            MarketPreCompute memory comp = state.getMarketPreCompute(pyIndexCurrent, block.timestamp);

            totalHypotheticalAsset =
                comp.totalAsset +
                state.totalPt.mulDown(int256(_getPtToAssetRate(market, state, pyIndexCurrent)));
        }

        return totalHypotheticalAsset.divDown(state.totalLp).Uint();
    }

    function getPtToAssetRate(address market) public view returns (uint256) {
        MarketState memory state = _readState(market);
        return _getPtToAssetRate(market, state, _pyIndex(market));
    }

    function getYtToAssetRate(address market) public view returns (uint256) {
        return PMath.ONE - getPtToAssetRate(market);
    }

    /// @param slippage A fixed-point number with 18 decimal places
    function swapExactSyForPtStaticAndGenerateApproxParams(
        address market,
        uint256 exactSyIn,
        uint256 slippage
    )
        external
        view
        returns (
            uint256 netPtOut,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            ApproxParams memory approxParams
        )
    {
        (netPtOut, netSyFee, priceImpact, exchangeRateAfter) = IPActionMarketCoreStatic(address(this))
            .swapExactSyForPtStatic(market, exactSyIn);
        approxParams = genApproxParamsToSwapExactSyForPt(market, netPtOut, slippage);
    }

    /// @param slippage A fixed-point number with 18 decimal places
    function swapExactTokenForPtStaticAndGenerateApproxParams(
        address market,
        address tokenIn,
        uint256 amountTokenIn,
        uint256 slippage
    )
        external
        view
        returns (
            uint256 netPtOut,
            uint256 netSyMinted,
            uint256 netSyFee,
            uint256 priceImpact,
            uint256 exchangeRateAfter,
            ApproxParams memory approxParams
        )
    {
        (netPtOut, netSyMinted, netSyFee, priceImpact, exchangeRateAfter) = IPActionMarketCoreStatic(address(this))
            .swapExactTokenForPtStatic(market, tokenIn, amountTokenIn);
        approxParams = genApproxParamsToSwapExactSyForPt(market, netPtOut, slippage);
    }

    /// @param slippage A fixed-point number with 18 decimal places
    function genApproxParamsToSwapExactSyForPt(
        address market,
        uint256 netPtOut,
        uint256 slippage
    ) public view returns (ApproxParams memory) {
        MarketState memory state = _readState(market);
        MarketPreCompute memory comp = state.getMarketPreCompute(_pyIndex(market), block.timestamp);

        uint256 guessLowerBound = 0;
        uint256 guessUpperBound = MarketApproxPtOutLib.calcMaxPtOut(comp, state.totalPt);
        return genApproxParamsPtOut(netPtOut, guessLowerBound, guessUpperBound, slippage);
    }

    /// @param slippage A fixed-point number with 18 decimal places
    function genApproxParamsPtOut(
        uint256 netPtOut,
        uint256 guessLowerBound,
        uint256 guessUpperBound,
        uint256 slippage
    ) internal pure returns (ApproxParams memory) {
        uint256 guessOffchain = netPtOut;
        uint256 MAX_ITERATION = 30;

        uint256 MIN_EPS_CAP = PMath.ONE / 10 ** 5;
        uint256 eps = PMath.min(slippage / 2, MIN_EPS_CAP);

        uint256 guessMin = PMath.max(guessLowerBound, netPtOut.slipDown(slippage));
        uint256 guessMax = PMath.min(guessUpperBound, netPtOut.slipUp(5 * slippage));

        return
            ApproxParams({
                guessOffchain: guessOffchain,
                maxIteration: MAX_ITERATION,
                eps: eps,
                guessMin: guessMin,
                guessMax: guessMax
            });
    }

    function _getPtToAssetRate(
        address market,
        MarketState memory state,
        PYIndex pyIndexCurrent
    ) internal view returns (uint256 ptToAssetRate) {
        if (state.expiry <= block.timestamp) {
            (IStandardizedYield SY, , ) = _readTokens(market);
            return (SY.exchangeRate().divDown(PYIndex.unwrap(pyIndexCurrent)));
        }
        uint256 timeToExpiry = state.expiry - block.timestamp;
        int256 assetToPtRate = MarketMathCore._getExchangeRateFromImpliedRate(state.lastLnImpliedRate, timeToExpiry);

        ptToAssetRate = uint256(PMath.IONE.divDown(assetToPtRate));
    }

    function _getPtImpliedYield(address market) internal view returns (int256) {
        MarketState memory state = _readState(market);

        int256 lnImpliedRate = (state.lastLnImpliedRate).Int();
        return lnImpliedRate.exp();
    }

    function _calcVirtualYTPrice(uint256 ptAssetExchangeRate) private pure returns (uint256 ytAssetExchangeRate) {
        // 1 asset = EX pt
        // 1 pt = 1/EX Asset
        // 1 yt + 1/EX Asset = 1 Asset
        // 1 yt = 1 Asset - 1/EX Asset
        // 1 yt = (EX - 1) / EX Asset
        return (ptAssetExchangeRate - PMath.ONE).divDown(ptAssetExchangeRate);
    }

    function _readState(address market) internal view returns (MarketState memory) {
        return IPMarket(market).readState(address(this));
    }

    function _readTokens(
        address market
    ) internal view returns (IStandardizedYield _SY, IPPrincipalToken _PT, IPYieldToken _YT) {
        return IPMarket(market).readTokens();
    }

    function _getSign(int256 netPtOut) private pure returns (int256) {
        return netPtOut > 0 ? int256(1) : int256(-1);
    }

    function _calculateImpact(uint256 rateBefore, uint256 rateTraded) private pure returns (uint256 impact) {
        impact = (rateBefore.Int() - rateTraded.Int()).abs().divDown(rateBefore);
    }

    function _pyIndex(address market) private view returns (PYIndex) {
        return PYIndex.wrap(IPRouterStatic(address(this)).pyIndexCurrentViewMarket(market));
    }
}
