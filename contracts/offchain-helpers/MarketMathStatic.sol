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
        MarketState memory state = IPMarket(market).readState();
        (, netLpOut, netSyUsed, netPtUsed) = state.addLiquidity(
            netSyDesired,
            netPtDesired,
            block.timestamp
        );
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
            uint256 netSyFee,
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

        uint256 netSyReceived;
        (netSyReceived, netSyFee) = state.swapExactPtForSy(
            pyIndex(market),
            netPtToSwap,
            block.timestamp
        );
        (, netLpOut, , ) = state.addLiquidity(
            netSyReceived,
            netPtIn - netPtToSwap,
            block.timestamp
        );

        priceImpact = calcPriceImpact(market, netPtToSwap.neg());
    }

    /// @dev netPtFromSwap is the parameter to approx
    function addLiquiditySingleSyStatic(
        address market,
        uint256 netSyIn,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (netPtFromSwap, , ) = state.approxSwapSyToAddLiquidity(
            pyIndex(market),
            netSyIn,
            block.timestamp,
            approxParams
        );

        state = IPMarket(market).readState(); // re-read

        uint256 netSySwap;
        (netSySwap, netSyFee) = state.swapSyForExactPt(
            pyIndex(market),
            netPtFromSwap,
            block.timestamp
        );
        (, netLpOut, , ) = state.addLiquidity(netSyIn - netSySwap, netPtFromSwap, block.timestamp);

        priceImpact = calcPriceImpact(market, netPtFromSwap.Int());
    }

    function removeLiquidityDualSyAndPtStatic(address market, uint256 netLpToRemove)
        external
        view
        returns (uint256 netSyOut, uint256 netPtOut)
    {
        MarketState memory state = IPMarket(market).readState();
        (netSyOut, netPtOut) = state.removeLiquidity(netLpToRemove);
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
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (uint256 syFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);
        (netPtFromSwap, netSyFee) = state.approxSwapExactSyForPt(
            pyIndex(market),
            syFromBurn,
            block.timestamp,
            approxParams
        );

        netPtOut = ptFromBurn + netPtFromSwap;
        priceImpact = calcPriceImpact(market, netPtFromSwap.Int());
    }

    function removeLiquiditySingleSyStatic(address market, uint256 netLpToRemove)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (uint256 syFromBurn, uint256 ptFromBurn) = state.removeLiquidity(netLpToRemove);

        if (IPMarket(market).isExpired()) {
            netSyOut = syFromBurn + pyIndex(market).assetToSy(ptFromBurn);
        } else {
            uint256 syFromSwap;
            (syFromSwap, netSyFee) = state.swapExactPtForSy(
                pyIndex(market),
                ptFromBurn,
                block.timestamp
            );

            netSyOut = syFromBurn + syFromSwap;
            priceImpact = calcPriceImpact(market, ptFromBurn.neg());
        }
    }

    function swapExactPtForSyStatic(address market, uint256 exactPtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        (netSyOut, netSyFee) = state.swapExactPtForSy(pyIndex(market), exactPtIn, block.timestamp);
        priceImpact = calcPriceImpact(market, exactPtIn.neg());
    }

    function swapSyForExactPtStatic(address market, uint256 exactPtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        (netSyIn, netSyFee) = state.swapSyForExactPt(pyIndex(market), exactPtOut, block.timestamp);
        priceImpact = calcPriceImpact(market, exactPtOut.Int());
    }

    /// @dev netPtOut is the parameter to approx
    function swapExactSyForPtStatic(
        address market,
        uint256 exactSyIn,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netPtOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        (netPtOut, netSyFee) = state.approxSwapExactSyForPt(
            pyIndex(market),
            exactSyIn,
            block.timestamp,
            approxParams
        );
        priceImpact = calcPriceImpact(market, netPtOut.Int());
    }

    /// @dev netPtIn is the parameter to approx
    function swapPtForExactSyStatic(
        address market,
        uint256 exactSyOut,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netPtIn,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        (netPtIn, , netSyFee) = state.approxSwapPtForExactSy(
            pyIndex(market),
            exactSyOut,
            block.timestamp,
            approxParams
        );
        priceImpact = calcPriceImpact(market, netPtIn.neg());
    }

    function swapSyForExactYtStatic(address market, uint256 exactYtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        PYIndex index = pyIndex(market);

        uint256 syReceived;
        (syReceived, netSyFee) = state.swapExactPtForSy(
            pyIndex(market),
            exactYtOut,
            block.timestamp
        );

        uint256 totalSyNeed = index.assetToSyUp(exactYtOut);
        netSyIn = totalSyNeed.subMax0(syReceived);

        priceImpact = calcPriceImpact(market, exactYtOut.neg());
    }

    /// @dev netYtOut is the parameter to approx
    function swapExactSyForYtStatic(
        address market,
        uint256 exactSyIn,
        ApproxParams memory approxParams
    )
        public
        returns (
            uint256 netYtOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        PYIndex index = pyIndex(market);

        (netYtOut, netSyFee) = state.approxSwapExactSyForYt(
            index,
            exactSyIn,
            block.timestamp,
            approxParams
        );

        priceImpact = calcPriceImpact(market, netYtOut.neg());
    }

    function swapExactYtForSyStatic(address market, uint256 exactYtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        PYIndex index = pyIndex(market);

        uint256 syOwed;
        (syOwed, netSyFee) = state.swapSyForExactPt(index, exactYtIn, block.timestamp);

        uint256 amountPYToRepaySyOwed = index.syToAssetUp(syOwed);
        uint256 amountPYToRedeemSyOut = exactYtIn - amountPYToRepaySyOwed;

        netSyOut = index.assetToSy(amountPYToRedeemSyOut);
        priceImpact = calcPriceImpact(market, exactYtIn.Int());
    }

    /// @dev netYtIn is the parameter to approx
    function swapYtForExactSyStatic(
        address market,
        uint256 exactSyOut,
        ApproxParams memory approxParams
    )
        external
        returns (
            uint256 netYtIn,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();

        PYIndex index = pyIndex(market);

        (netYtIn, , netSyFee) = state.approxSwapYtForExactSy(
            index,
            exactSyOut,
            block.timestamp,
            approxParams
        );
        priceImpact = calcPriceImpact(market, netYtIn.Int());
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
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        PYIndex index = pyIndex(market);

        (netYtOut, totalPtToSwap, netSyFee) = state.approxSwapExactPtForYt(
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
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        MarketState memory state = IPMarket(market).readState();
        PYIndex index = pyIndex(market);

        (netPtOut, totalPtSwapped, netSyFee) = state.approxSwapExactYtForPt(
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
