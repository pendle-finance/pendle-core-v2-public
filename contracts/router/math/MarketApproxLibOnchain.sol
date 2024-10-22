// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../core/libraries/math/PMath.sol";
import "../../core/Market/MarketMathCore.sol";
import {ApproxParams} from "../../interfaces/IPAllActionTypeV3.sol";
import {ApproxState, ApproxStateLib} from "./ApproxStateLib.sol";
import {MarketApproxEstimateLib} from "./MarketApproxEstimateLib.sol";

library MarketApproxPtInLibOnchain {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;
    using MarketApproxEstimateLib for MarketState;

    function approxSwapExactSyForYtOnchain(
        MarketState memory market,
        PYIndex index,
        uint256 exactSyIn,
        uint256 blockTime
    ) internal pure returns (uint256, /*netYtOut*/ uint256, /*netSyFee*/ uint256 /* iteration */) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        uint256 estimatedYtOut = market.estimateSwapExactSyForYt(index, blockTime, exactSyIn);
        uint256[2] memory hardBounds = [index.syToAsset(exactSyIn), calcSoftMaxPtIn(market, comp)];
        ApproxState memory state = ApproxStateLib.initNoOffChain(estimatedYtOut, hardBounds);

        for (uint256 iter = 0; iter < state.maxIteration; ++iter) {
            uint256 guess = state.curGuess;
            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(market, comp, index, guess);

            uint256 netSyToTokenizePt = index.assetToSyUp(guess);

            uint256 netSyToPull = netSyToTokenizePt - netSyOut;

            if (netSyToPull <= exactSyIn) {
                if (PMath.isASmallerApproxB(netSyToPull, exactSyIn, state.eps)) {
                    return (guess, netSyFee, iter);
                }
                state.transitionUp({excludeGuessFromRange: false});
            } else {
                state.transitionDown({excludeGuessFromRange: true});
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    function approxSwapPtToAddLiquidityOnchain(
        MarketState memory market,
        PYIndex index,
        uint256 totalPtIn,
        uint256 netSyHolding,
        uint256 blockTime
    )
        internal
        pure
        returns (uint256, /*netPtSwap*/ uint256, /*netSyFromSwap*/ uint256, /*netSyFee*/ uint256 /* iteration */)
    {
        require(market.totalLp != 0, "no existing lp");

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        (uint256 estimatedPtAdd, ) = market.estimateAddLiquidity(index, blockTime, totalPtIn, netSyHolding);
        uint256 estimatedPtSwap = totalPtIn.subMax0(estimatedPtAdd);
        uint256[2] memory hardBounds = [0, PMath.min(totalPtIn, calcSoftMaxPtIn(market, comp))];
        ApproxState memory state = ApproxStateLib.initNoOffChain(estimatedPtSwap, hardBounds);

        for (uint256 iter = 0; iter < state.maxIteration; ++iter) {
            uint256 guess = state.curGuess;
            (uint256 syNumerator, uint256 ptNumerator, uint256 netSyOut, uint256 netSyFee, ) = (
                calcNumerators(market, index, totalPtIn, netSyHolding, comp, guess)
            );

            if (PMath.isAApproxB(syNumerator, ptNumerator, state.eps)) {
                return (guess, netSyOut, netSyFee, iter);
            }

            if (syNumerator <= ptNumerator) {
                // needs more SY --> swap more PT
                state.transitionUp({excludeGuessFromRange: true});
            } else {
                // needs less SY --> swap less PT
                state.transitionDown({excludeGuessFromRange: true});
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    function calcNumerators(
        MarketState memory market,
        PYIndex index,
        uint256 totalPtIn,
        uint256 netSyHolding,
        MarketPreCompute memory comp,
        uint256 guess
    )
        internal
        pure
        returns (uint256 syNumerator, uint256 ptNumerator, uint256 netSyOut, uint256 netSyFee, uint256 netSyToReserve)
    {
        (netSyOut, netSyFee, netSyToReserve) = calcSyOut(market, comp, index, guess);

        uint256 newTotalPt = uint256(market.totalPt) + guess;
        uint256 newTotalSy = (uint256(market.totalSy) - netSyOut - netSyToReserve);

        syNumerator = (netSyOut + netSyHolding) * newTotalPt;
        ptNumerator = (totalPtIn - guess) * newTotalSy;
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcSyOut(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtIn
    ) internal pure returns (uint256 netSyOut, uint256 netSyFee, uint256 netSyToReserve) {
        (int256 _netSyOut, int256 _netSyFee, int256 _netSyToReserve) = market.calcTrade(comp, index, -int256(netPtIn));
        netSyOut = uint256(_netSyOut);
        netSyFee = uint256(_netSyFee);
        netSyToReserve = uint256(_netSyToReserve);
    }

    function calcSoftMaxPtIn(MarketState memory market, MarketPreCompute memory comp) internal pure returns (uint256) {
        return (MarketMathCore.MAX_MARKET_PROPORTION.mulDown(market.totalPt + comp.totalAsset) - market.totalPt).Uint();
    }
}

library MarketApproxPtOutLibOnchain {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;
    using MarketApproxEstimateLib for MarketState;

    function approxSwapExactSyForPtOnchain(
        MarketState memory market,
        PYIndex index,
        uint256 exactSyIn,
        uint256 blockTime
    ) internal pure returns (uint256, /*netPtOut*/ uint256, /*netSyFee*/ uint256 /* iteration */) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        uint256 estimatedPtOut = market.estimateSwapExactSyForPt(index, blockTime, exactSyIn);
        uint256[2] memory hardBounds = [0, calcMaxPtOut(comp, market.totalPt)];
        ApproxState memory state = ApproxStateLib.initNoOffChain(estimatedPtOut, hardBounds);

        for (uint256 iter = 0; iter < state.maxIteration; ++iter) {
            uint256 guess = state.curGuess;
            (uint256 netSyIn, uint256 netSyFee, ) = calcSyIn(market, comp, index, guess);

            if (netSyIn <= exactSyIn) {
                if (PMath.isASmallerApproxB(netSyIn, exactSyIn, state.eps)) {
                    return (guess, netSyFee, iter);
                }
                state.transitionUp({excludeGuessFromRange: false});
            } else {
                state.transitionDown({excludeGuessFromRange: true});
            }
        }

        revert("Slippage: APPROX_EXHAUSTED");
    }

    function approxSwapSyToAddLiquidityOnchain(
        MarketState memory market,
        PYIndex index,
        uint256 totalSyIn,
        uint256 netPtHolding,
        uint256 blockTime
    )
        internal
        pure
        returns (uint256, /*netPtFromSwap*/ uint256, /*netSySwap*/ uint256, /*netSyFee*/ uint256 /* iteration */)
    {
        require(market.totalLp != 0, "no existing lp");

        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        (uint256 estimatedPtAdd, ) = market.estimateAddLiquidity(index, blockTime, netPtHolding, totalSyIn);
        uint256 estimatedPtSwap = estimatedPtAdd.subMax0(netPtHolding);
        uint256[2] memory hardBounds = [0, calcMaxPtOut(comp, market.totalPt)];
        ApproxState memory state = ApproxStateLib.initNoOffChain(estimatedPtSwap, hardBounds);

        for (uint256 iter = 0; iter < state.maxIteration; ++iter) {
            uint256 guess = state.curGuess;
            (uint256 netSyIn, uint256 netSyFee, uint256 netSyToReserve) = calcSyIn(market, comp, index, guess);

            if (netSyIn > totalSyIn) {
                state.transitionDown({excludeGuessFromRange: true});
                continue;
            }

            uint256 syNumerator;
            uint256 ptNumerator;

            {
                uint256 newTotalPt = uint256(market.totalPt) - guess;
                uint256 netTotalSy = uint256(market.totalSy) + netSyIn - netSyToReserve;

                ptNumerator = (guess + netPtHolding) * netTotalSy;
                syNumerator = (totalSyIn - netSyIn) * newTotalPt;
            }

            if (PMath.isAApproxB(ptNumerator, syNumerator, state.eps)) {
                return (guess, netSyIn, netSyFee, iter);
            }

            if (ptNumerator <= syNumerator) {
                // needs more PT
                state.transitionUp({excludeGuessFromRange: true});
            } else {
                // needs less PT
                state.transitionDown({excludeGuessFromRange: true});
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcSyIn(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtOut
    ) internal pure returns (uint256 netSyIn, uint256 netSyFee, uint256 netSyToReserve) {
        (int256 _netSyIn, int256 _netSyFee, int256 _netSyToReserve) = market.calcTrade(comp, index, int256(netPtOut));

        netSyIn = uint256(-_netSyIn);
        netSyFee = uint256(_netSyFee);
        netSyToReserve = uint256(_netSyToReserve);
    }

    function calcMaxPtOut(MarketPreCompute memory comp, int256 totalPt) internal pure returns (uint256) {
        int256 logitP = (comp.feeRate - comp.rateAnchor).mulDown(comp.rateScalar).exp();
        int256 proportion = logitP.divDown(logitP + PMath.IONE);
        int256 numerator = proportion.mulDown(totalPt + comp.totalAsset);
        int256 maxPtOut = totalPt - numerator;
        return (uint256(maxPtOut) * 999) / 1000;
    }
}
