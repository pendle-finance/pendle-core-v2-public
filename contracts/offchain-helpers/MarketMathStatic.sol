// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../libraries/math/MarketApproxLib.sol";
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

    function addLiquidityDualScyAndPtStatic(
        address market,
        uint256 netScyDesired,
        uint256 netPtDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netScyUsed,
            uint256 netPtUsed
        )
    {
        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, netScyUsed, netPtUsed) = state.addLiquidity(
            netScyDesired,
            netPtDesired,
            block.timestamp
        );
    }

    function addLiquidityDualTokenAndPtStatic(
        address market,
        address tokenIn,
        uint256 netTokenDesired,
        uint256 netPtDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netTokenUsed,
            uint256 netPtUsed
        )
    {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 scyDesired = SCY.previewDeposit(tokenIn, netTokenDesired);
        uint256 scyUsed;

        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, scyUsed, netPtUsed) = state.addLiquidity(
            scyDesired,
            netPtDesired,
            block.timestamp
        );

        netTokenUsed = (netTokenDesired * scyUsed).rawDivUp(scyDesired);
    }

    /// @dev netPtToSwap is the parameter to approx
    function addLiquiditySinglePtStatic(
        address market,
        uint256 netPtIn,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netPtToSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (netPtToSwap, , ) = state.approxSwapPtToAddLiquidity(
            pyIndex(market),
            netPtIn,
            block.timestamp,
            approxParams
        );

        state = IPMarket(market).readState(); // re-read

        uint256 netScyReceived;
        (netScyReceived, netScyFee) = state.swapExactPtForScy(
            pyIndex(market),
            netPtToSwap,
            block.timestamp
        );
        (, netLpOut, , ) = state.addLiquidity(
            netScyReceived,
            netPtIn - netPtToSwap,
            block.timestamp
        );

        priceImpact = calcPriceImpact(market, netPtToSwap.neg());
    }

    /// @dev netPtFromSwap is the parameter to approx
    function addLiquiditySingleScyStatic(
        address market,
        uint256 netScyIn,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (netPtFromSwap, , ) = state.approxSwapScyToAddLiquidity(
            pyIndex(market),
            netScyIn,
            block.timestamp,
            approxParams
        );

        state = IPMarket(market).readState(); // re-read

        uint256 netScySwap;
        (netScySwap, netScyFee) = state.swapScyForExactPt(
            pyIndex(market),
            netPtFromSwap,
            block.timestamp
        );
        (, netLpOut, , ) = state.addLiquidity(
            netScyIn - netScySwap,
            netPtFromSwap,
            block.timestamp
        );

        priceImpact = calcPriceImpact(market, netPtFromSwap.Int());
    }

    /// @dev netPtFromSwap is the parameter to approx
    function addLiquiditySingleBaseTokenStatic(
        address market,
        address baseToken,
        uint256 netBaseTokenIn,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
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

    function removeLiquidityDualScyAndPtStatic(address market, uint256 netLpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netPtOut)
    {
        MarketState memory state = IPMarket(market).readState();
        (netScyOut, netPtOut) = state.removeLiquidity(netLpToRemove);
    }

    function removeLiquidityDualTokenAndPtStatic(
        address market,
        uint256 metLpToRemove,
        address tokenOut
    ) external view returns (uint256 netTokenOut, uint256 netPtOut) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        uint256 netScyOut;
        MarketState memory state = IPMarket(market).readState();
        (netScyOut, netPtOut) = state.removeLiquidity(metLpToRemove);

        netTokenOut = SCY.previewRedeem(tokenOut, netScyOut);
    }

    /// @dev netPtFromSwap is the parameter to approx
    function removeLiquiditySinglePtStatic(
        address market,
        uint256 netLpToRemove,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netPtOut,
            uint256 netPtFromSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (uint256 scyFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);
        (netPtFromSwap, , netScyFee) = state.approxSwapExactScyForPt(
            pyIndex(market),
            scyFromBurn,
            block.timestamp,
            approxParams
        );

        netPtOut = ptFromBurn + netPtFromSwap;
        priceImpact = calcPriceImpact(market, netPtFromSwap.Int());
    }

    function removeLiquiditySingleScyStatic(address market, uint256 netLpToRemove)
        public
        returns (
            uint256 netScyOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (uint256 scyFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);

        if (IPMarket(market).isExpired()) {
            netScyOut = scyFromBurn + pyIndex(market).assetToScy(ptFromBurn);
        } else {
            uint256 scyFromSwap;
            (scyFromSwap, netScyFee) = state.swapExactPtForScy(
                pyIndex(market),
                ptFromBurn,
                block.timestamp
            );

            netScyOut = scyFromBurn + scyFromSwap;
            priceImpact = calcPriceImpact(market, ptFromBurn.neg());
        }
    }

    function removeLiquiditySingleBaseTokenStatic(
        address market,
        uint256 netLpToRemove,
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
        (netScyOut, netScyFee, priceImpact) = removeLiquiditySingleScyStatic(
            market,
            netLpToRemove
        );

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

    /// @dev netPtOut is the parameter to approx
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

    /// @dev netPtIn is the parameter to approx
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

    /// @dev netPtOut is the parameter to approx
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
        uint256 exactPtIn,
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
        (netScyOut, netScyFee, priceImpact) = swapExactPtForScyStatic(market, exactPtIn);

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

    /// @dev netYtOut is the parameter to approx
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

    /// @dev netYtIn is the parameter to approx
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

    /// @dev netYtOut is the parameter to approx
    function swapExactBaseTokenForYtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netYtOut,
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

    // totalPtToSwap is the param to approx
    function swapExactPtForYt(
        address market,
        uint256 exactPtIn,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netYtOut,
            uint256 totalPtToSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        PYIndex index = pyIndex(market);

        (netYtOut, , totalPtToSwap, netScyFee) = state.approxSwapExactPtForYt(
            index,
            exactPtIn,
            block.timestamp,
            approxParams
        );
        priceImpact = calcPriceImpact(market, totalPtToSwap.neg());
    }

    // totalPtSwapped is the param to approx
    function swapExactYtForPt(
        address market,
        uint256 exactYtIn,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netPtOut,
            uint256 totalPtSwapped,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        PYIndex index = pyIndex(market);

        (netPtOut, , totalPtSwapped, netScyFee) = state.approxSwapExactYtForPt(
            index,
            exactYtIn,
            block.timestamp,
            approxParams
        );

        priceImpact = calcPriceImpact(market, totalPtSwapped.Int());
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
        if (IPMarket(market).isExpired()) return Math.ONE;
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
            if (postFeeExchangeRate < Math.IONE)
                revert Errors.MarketExchangeRateBelowOne(postFeeExchangeRate);
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
