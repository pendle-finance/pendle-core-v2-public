// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketApproxLib.sol";
import "../interfaces/IPMarket.sol";

library MarketMathStatic {
    using MarketMathCore for MarketState;
    using MarketApproxLib for MarketState;
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;
    using PYIndexLib for PYIndex;
    using PYIndexLib for IPYieldToken;

    function addLiquidityDualScyAndPtStatic(
        address market,
        uint256 scyDesired,
        uint256 ptDesired
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 ptUsed
        )
    {
        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, scyUsed, ptUsed) = state.addLiquidity(
            pyIndex(market),
            scyDesired,
            ptDesired,
            block.timestamp
        );
    }

    function addLiquidityDualTokenAndPtStatic(
        address market,
        address tokenIn,
        uint256 tokenDesired,
        uint256 ptDesired
    )
        external
        returns (
            uint256 netLpOut,
            uint256 tokenUsed,
            uint256 ptUsed
        )
    {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 scyDesired = SCY.previewDeposit(tokenIn, tokenDesired);
        uint256 scyUsed;

        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, scyUsed, ptUsed) = state.addLiquidity(
            pyIndex(market),
            scyDesired,
            ptDesired,
            block.timestamp
        );

        tokenUsed = (tokenDesired * scyUsed).rawDivUp(scyDesired);
    }

    function addLiquiditySinglePtStatic(
        address market,
        uint256 netPtIn,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtSwap, , ) = state.approxSwapPtToAddLiquidity(
            pyIndex(market),
            netPtIn,
            block.timestamp,
            approxParams
        );

        uint256 netScyReceived;
        (netScyReceived, netScyFee) = state.swapExactPtForScy(
            pyIndex(market),
            netPtSwap,
            block.timestamp
        );
        (, netLpOut, , ) = state.addLiquidity(
            pyIndex(market),
            netScyReceived,
            netPtIn - netPtSwap,
            block.timestamp
        );

        priceImpact = calcPriceImpact(market, netPtSwap.neg());
    }

    function addLiquiditySingleScyStatic(
        address market,
        uint256 netScyIn,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netLpOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (uint256 netPtReceived, , ) = state.approxSwapScyToAddLiquidity(
            pyIndex(market),
            netScyIn,
            block.timestamp,
            approxParams
        );

        uint256 netScySwap;
        (netScySwap, netScyFee) = state.swapScyForExactPt(
            pyIndex(market),
            netPtReceived,
            block.timestamp
        );
        (, netLpOut, , ) = state.addLiquidity(
            pyIndex(market),
            netScyIn - netScySwap,
            netPtReceived,
            block.timestamp
        );

        priceImpact = calcPriceImpact(market, netPtReceived.Int());
    }

    function addLiquiditySingleBaseTokenStatic(
        address market,
        address baseToken,
        uint256 netBaseTokenIn,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        return
            addLiquiditySingleScyStatic(
                market,
                SCY.previewDeposit(baseToken, netBaseTokenIn),
                approxParams
            );
    }

    function removeLiquidityDualScyAndPtStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netPtOut)
    {
        MarketState memory state = IPMarket(market).readState();
        (netScyOut, netPtOut) = state.removeLiquidity(lpToRemove);
    }

    function removeLiquidityDualTokenAndPtStatic(
        address market,
        uint256 lpToRemove,
        address tokenOut
    ) external view returns (uint256 netTokenOut, uint256 netPtOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 netScyOut;
        MarketState memory state = IPMarket(market).readState();
        (netScyOut, netPtOut) = state.removeLiquidity(lpToRemove);

        netTokenOut = SCY.previewRedeem(tokenOut, netScyOut);
    }

    function removeLiquiditySinglePtStatic(
        address market,
        uint256 lpToRemove,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netPtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (uint256 scyFromBurn, uint256 ptFromBurn) = state.removeLiquidity(lpToRemove);
        uint256 ptFromSwap;
        (ptFromSwap, , netScyFee) = state.approxSwapExactScyForPt(
            pyIndex(market),
            scyFromBurn,
            block.timestamp,
            approxParams
        );

        netPtOut = ptFromBurn + ptFromSwap;
        priceImpact = calcPriceImpact(market, ptFromSwap.Int());
    }

    function removeLiquiditySingleScyStatic(address market, uint256 lpToRemove)
        public
        returns (
            uint256 netScyOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (uint256 scyFromBurn, uint256 ptFromBurn) = state.removeLiquidity(lpToRemove);
        uint256 scyFromSwap;
        (scyFromSwap, netScyFee) = state.swapExactPtForScy(
            pyIndex(market),
            ptFromBurn,
            block.timestamp
        );

        netScyOut = scyFromBurn + scyFromSwap;
        priceImpact = calcPriceImpact(market, ptFromBurn.neg());
    }

    function removeLiquiditySingleBaseTokenStatic(
        address market,
        uint256 lpToRemove,
        address baseToken
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        uint256 netScyOut;
        (netScyOut, netScyFee, priceImpact) = removeLiquiditySingleScyStatic(market, lpToRemove);

        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();
        netBaseTokenOut = SCY.previewRedeem(baseToken, netScyOut);
    }

    function swapExactPtForScyStatic(address market, uint256 exactPtIn)
        public
        returns (
            uint256 netScyOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        (netScyOut, netScyFee) = state.swapExactPtForScy(
            pyIndex(market),
            exactPtIn,
            block.timestamp
        );
        priceImpact = calcPriceImpact(market, exactPtIn.neg());
    }

    function swapScyForExactPtStatic(address market, uint256 exactPtOut)
        external
        returns (
            uint256 netScyIn,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        (netScyIn, netScyFee) = state.swapScyForExactPt(
            pyIndex(market),
            exactPtOut,
            block.timestamp
        );
        priceImpact = calcPriceImpact(market, exactPtOut.Int());
    }

    function swapExactScyForPtStatic(
        address market,
        uint256 exactScyIn,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netPtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        (netPtOut, , netScyFee) = state.approxSwapExactScyForPt(
            pyIndex(market),
            exactScyIn,
            block.timestamp,
            approxParams
        );
        priceImpact = calcPriceImpact(market, netPtOut.Int());
    }

    function swapPtForExactScyStatic(
        address market,
        uint256 exactScyOut,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netPtIn,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (netPtIn, , netScyFee) = state.approxSwapPtForExactScy(
            pyIndex(market),
            exactScyOut,
            block.timestamp,
            approxParams
        );
        priceImpact = calcPriceImpact(market, netPtIn.neg());
    }

    function swapExactBaseTokenForPtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netPtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        return
            swapExactScyForPtStatic(
                market,
                SCY.previewDeposit(baseToken, amountBaseToken),
                approxParams
            );
    }

    function swapExactPtForBaseTokenStatic(
        address market,
        uint256 exactYtIn,
        address baseToken
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        uint256 netScyOut;
        (netScyOut, netScyFee, priceImpact) = swapExactPtForScyStatic(market, exactYtIn);

        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();
        netBaseTokenOut = SCY.previewRedeem(baseToken, netScyOut);
    }

    function swapScyForExactYtStatic(address market, uint256 exactYtOut)
        external
        returns (
            uint256 netScyIn,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        PYIndex index = pyIndex(market);

        uint256 scyReceived;
        (scyReceived, netScyFee) = state.swapExactPtForScy(
            pyIndex(market),
            exactYtOut,
            block.timestamp
        );

        uint256 totalScyNeed = index.assetToScyUp(exactYtOut);
        netScyIn = totalScyNeed.subMax0(scyReceived);

        priceImpact = calcPriceImpact(market, exactYtOut.neg());
    }

    function swapExactScyForYtStatic(
        address market,
        uint256 exactScyIn,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netYtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        PYIndex index = pyIndex(market);

        (netYtOut, , netScyFee) = state.approxSwapExactScyForYt(
            index,
            exactScyIn,
            block.timestamp,
            approxParams
        );

        priceImpact = calcPriceImpact(market, netYtOut.neg());
    }

    function swapExactYtForScyStatic(address market, uint256 exactYtIn)
        public
        returns (
            uint256 netScyOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        PYIndex index = pyIndex(market);

        uint256 scyOwed;
        (scyOwed, netScyFee) = state.swapScyForExactPt(index, exactYtIn, block.timestamp);

        uint256 amountPYToRepayScyOwed = index.scyToAssetUp(scyOwed);
        uint256 amountPYToRedeemScyOut = exactYtIn - amountPYToRepayScyOwed;

        netScyOut = index.assetToScy(amountPYToRedeemScyOut);
        priceImpact = calcPriceImpact(market, exactYtIn.Int());
    }

    function swapYtForExactScyStatic(
        address market,
        uint256 exactScyOut,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netYtIn,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        PYIndex index = pyIndex(market);

        (netYtIn, , netScyFee) = state.approxSwapYtForExactScy(
            index,
            exactScyOut,
            block.timestamp,
            approxParams
        );
        priceImpact = calcPriceImpact(market, netYtIn.Int());
    }

    function swapExactYtForBaseTokenStatic(
        address market,
        uint256 exactYtIn,
        address baseToken
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        uint256 netScyOut;
        (netScyOut, netScyFee, priceImpact) = swapExactYtForScyStatic(market, exactYtIn);

        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();
        netBaseTokenOut = SCY.previewRedeem(baseToken, netScyOut);
    }

    function swapExactBaseTokenForYtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netPtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        return
            swapExactScyForYtStatic(
                market,
                SCY.previewDeposit(baseToken, amountBaseToken),
                approxParams
            );
    }

    function pyIndex(address market) public returns (PYIndex index) {
        (, , IPYieldToken YT) = IPMarket(market).readTokens();

        return YT.newIndex();
    }

    function getExchangeRate(address market) public returns (uint256) {
        return getTradeExchangeRateIncludeFee(market, 0);
    }

    function getTradeExchangeRateIncludeFee(address market, int256 netPtOut)
        public
        returns (uint256)
    {
        int256 netPtToAccount = netPtOut;
        MarketState memory state = IPMarket(market).readState();
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
            require(postFeeExchangeRate >= Math.IONE, "exchange rate below 1");
            return postFeeExchangeRate.Uint();
        } else {
            return preFeeExchangeRate.mulDown(comp.feeRate).Uint();
        }
    }

    function calcPriceImpact(address market, int256 netPtOut)
        public
        returns (uint256 priceImpact)
    {
        uint256 preTradeRate = getExchangeRate(market);
        uint256 tradedRate = getTradeExchangeRateIncludeFee(market, netPtOut);

        priceImpact = (tradedRate.Int() - preTradeRate.Int()).abs().divDown(preTradeRate);
    }

    function getPtImpliedYield(address market) public view returns (int256) {
        MarketState memory state = IPMarket(market).readState();

        int256 lnImpliedRate = (state.lastLnImpliedRate).Int();
        return lnImpliedRate.exp();
    }
}
