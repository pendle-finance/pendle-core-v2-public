// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../core/libraries/math/PMath.sol";
import "../../core/Market/MarketMathCore.sol";
import {ApproxParams} from "../../interfaces/IPAllActionTypeV3.sol";

uint256 constant QUICK_CALC_MAX_ITER = 50;
uint256 constant CUT_OFF_SCALE_CLAMP = 2;
uint256 constant QUICK_CALC_TRIGGER_EPS = 1e17;

library MarketApproxPtInLibV2 {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;

    function approxSwapExactSyForYtV2(
        MarketState memory market,
        PYIndex index,
        uint256 exactSyIn,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256, /*netYtOut*/ uint256 /*netSyFee*/) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessOffchain == 0) {
            approx.guessMin = PMath.max(approx.guessMin, index.syToAsset(exactSyIn));
            approx.guessMax = PMath.min(approx.guessMax, calcMaxPtIn(market, comp));
            validateApprox(approx);
        }

        // at minimum we will flashswap exactSyIn since we have enough SY to payback the PT loan

        uint256 guess = getFirstGuess(approx);

        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            (uint256 netSyOut, uint256 netSyFee, ) = calcSyOut(market, comp, index, guess);

            uint256 netSyToTokenizePt = index.assetToSyUp(guess);

            // for sure netSyToTokenizePt >= netSyOut since we are swapping PT to SY
            uint256 netSyToPull = netSyToTokenizePt - netSyOut;

            if (netSyToPull <= exactSyIn) {
                if (PMath.isASmallerApproxB(netSyToPull, exactSyIn, approx.eps)) {
                    return (guess, netSyFee);
                }
                if (approx.guessMin == guess) {
                    break;
                }
                approx.guessMin = guess;
            } else {
                approx.guessMax = guess - 1;
            }

            if (iter <= CUT_OFF_SCALE_CLAMP) {
                guess = scaleClamp(guess, exactSyIn, netSyToPull, approx);
            } else {
                guess = calcMidpoint(approx);
            }
        }

        revert("Slippage: APPROX_EXHAUSTED");
    }

    struct Args5 {
        MarketState market;
        PYIndex index;
        uint256 totalPtIn;
        uint256 netSyHolding;
        uint256 blockTime;
        ApproxParams approx;
    }

    function approxSwapPtToAddLiquidityV2(
        MarketState memory _market,
        PYIndex _index,
        uint256 _totalPtIn,
        uint256 _netSyHolding,
        uint256 _blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256, /*netPtSwap*/ uint256, /*netSyFromSwap*/ uint256 /*netSyFee*/) {
        Args5 memory a = Args5(_market, _index, _totalPtIn, _netSyHolding, _blockTime, approx);
        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        if (approx.guessOffchain == 0) {
            // no limit on min
            approx.guessMax = PMath.min(approx.guessMax, calcMaxPtIn(a.market, comp));
            approx.guessMax = PMath.min(approx.guessMax, a.totalPtIn);
            validateApprox(approx);
            require(a.market.totalLp != 0, "no existing lp");
        }

        uint256 guess = getFirstGuess(approx);

        bool quickCalcRan = false;
        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            (
                uint256 syNumerator,
                uint256 ptNumerator,
                uint256 netSyOut,
                uint256 netSyFee,
                uint256 netSyToReserve
            ) = calcNumerators(a.market, a.index, a.totalPtIn, a.netSyHolding, comp, guess);

            if (PMath.isAApproxB(syNumerator, ptNumerator, approx.eps)) {
                return (guess, netSyOut, netSyFee);
            }

            if (syNumerator <= ptNumerator) {
                // needs more SY --> swap more PT
                if (approx.guessMin == guess) {
                    break;
                }
                approx.guessMin = guess;
            } else {
                // needs less SY --> swap less PT
                approx.guessMax = guess - 1;
            }

            if (!quickCalcRan && PMath.isAApproxB(syNumerator, ptNumerator, QUICK_CALC_TRIGGER_EPS)) {
                quickCalcRan = true;
                guess = quickCalc(a, guess, netSyOut, netSyToReserve);
                if (guess <= a.approx.guessMin || guess >= a.approx.guessMax) guess = calcMidpoint(a.approx);
            } else {
                guess = calcMidpoint(a.approx);
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    function quickCalc(
        Args5 memory a,
        uint256 _guess,
        uint256 _netSyOut,
        uint256 _netSyToReserve
    ) internal pure returns (uint256) {
        unchecked {
            uint256 low = a.approx.guessMin;
            uint256 high = a.approx.guessMax;

            for (uint256 i = 0; i < QUICK_CALC_MAX_ITER; i++) {
                uint256 mid = (low + high) / 2;

                uint256 thisNetSyOut = (_netSyOut * mid) / _guess;
                uint256 thisNetSyToReserve = (_netSyToReserve * mid) / _guess;

                uint256 newTotalPt = uint256(a.market.totalPt) + mid;
                uint256 newTotalSy = (uint256(a.market.totalSy) - thisNetSyOut - thisNetSyToReserve);

                uint256 syNumerator = (thisNetSyOut + a.netSyHolding) * newTotalPt;
                uint256 ptNumerator = (a.totalPtIn - mid) * newTotalSy;

                if (isAApproxBUnchecked(syNumerator, ptNumerator, a.approx.eps)) {
                    return mid;
                }

                if (syNumerator <= ptNumerator) {
                    if (low == mid) {
                        break;
                    }
                    low = mid;
                } else {
                    high = mid - 1;
                }

                if (low > high) return mid;
            }
            return (low + high) / 2;
        }
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

        // it is desired that
        // (netSyOut + netSyHolding) / newTotalSy = netPtRemaining / newTotalPt
        // which is equivalent to
        // (netSyOut + netSyHolding) * newTotalPt = netPtRemaining * newTotalSy

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

    /// INTENDED TO BE CALLED BY WHEN GUESS.OFFCHAIN == 0 ONLY ///

    function validateApprox(ApproxParams memory approx) internal pure {
        if (approx.guessMin > approx.guessMax || approx.eps > PMath.ONE) revert("Internal: INVALID_APPROX_PARAMS");
    }

    function calcMaxPtIn(MarketState memory market, MarketPreCompute memory comp) internal pure returns (uint256) {
        uint256 low = 0;
        uint256 hi = uint256(comp.totalAsset) - 1;

        while (low != hi) {
            uint256 mid = (low + hi + 1) / 2;
            if (calcSlope(comp, market.totalPt, int256(mid)) < 0) hi = mid - 1;
            else low = mid;
        }

        low = PMath.min(
            low,
            (MarketMathCore.MAX_MARKET_PROPORTION.mulDown(market.totalPt + comp.totalAsset) - market.totalPt).Uint()
        );

        return low;
    }

    function calcSlope(MarketPreCompute memory comp, int256 totalPt, int256 ptToMarket) internal pure returns (int256) {
        int256 diffAssetPtToMarket = comp.totalAsset - ptToMarket;
        int256 sumPt = ptToMarket + totalPt;

        require(diffAssetPtToMarket > 0 && sumPt > 0, "invalid ptToMarket");

        int256 part1 = (ptToMarket * (totalPt + comp.totalAsset)).divDown(sumPt * diffAssetPtToMarket);

        int256 part2 = sumPt.divDown(diffAssetPtToMarket).ln();
        int256 part3 = PMath.IONE.divDown(comp.rateScalar);

        return comp.rateAnchor - (part1 - part2).mulDown(part3);
    }
}

library MarketApproxPtOutLibV2 {
    using MarketMathCore for MarketState;
    using PYIndexLib for PYIndex;
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;

    function approxSwapExactSyForPtV2(
        MarketState memory market,
        PYIndex index,
        uint256 exactSyIn,
        uint256 blockTime,
        ApproxParams memory approx
    ) internal pure returns (uint256, /*netPtOut*/ uint256 /*netSyFee*/) {
        MarketPreCompute memory comp = market.getMarketPreCompute(index, blockTime);
        if (approx.guessOffchain == 0) {
            // no limit on min
            approx.guessMax = PMath.min(approx.guessMax, calcMaxPtOut(comp, market.totalPt));
            validateApprox(approx);
        }
        uint256 guess = getFirstGuess(approx);

        for (uint256 iter = 0; iter < approx.maxIteration; ++iter) {
            (uint256 netSyIn, uint256 netSyFee, ) = calcSyIn(market, comp, index, guess);

            if (netSyIn <= exactSyIn) {
                if (PMath.isASmallerApproxB(netSyIn, exactSyIn, approx.eps)) {
                    return (guess, netSyFee);
                }
                if (guess == approx.guessMin) {
                    break;
                }
                approx.guessMin = guess;
            } else {
                approx.guessMax = guess - 1;
            }

            if (iter <= CUT_OFF_SCALE_CLAMP) {
                guess = scaleClamp(guess, exactSyIn, netSyIn, approx);
            } else {
                guess = calcMidpoint(approx);
            }
        }

        revert("Slippage: APPROX_EXHAUSTED");
    }

    struct Args6 {
        MarketState market;
        PYIndex index;
        uint256 totalSyIn;
        uint256 netPtHolding;
        uint256 blockTime;
        ApproxParams approx;
    }

    function approxSwapSyToAddLiquidityV2(
        MarketState memory _market,
        PYIndex _index,
        uint256 _totalSyIn,
        uint256 _netPtHolding,
        uint256 _blockTime,
        ApproxParams memory _approx
    ) internal pure returns (uint256, /*netPtFromSwap*/ uint256, /*netSySwap*/ uint256 /*netSyFee*/) {
        Args6 memory a = Args6(_market, _index, _totalSyIn, _netPtHolding, _blockTime, _approx);

        MarketPreCompute memory comp = a.market.getMarketPreCompute(a.index, a.blockTime);
        if (a.approx.guessOffchain == 0) {
            // no limit on min
            a.approx.guessMax = PMath.min(a.approx.guessMax, calcMaxPtOut(comp, a.market.totalPt));
            validateApprox(a.approx);
            require(a.market.totalLp != 0, "no existing lp");
        }

        uint256 guess = getFirstGuess(a.approx);

        bool quickCalcRan = false;
        for (uint256 iter = 0; iter < a.approx.maxIteration; ++iter) {
            (uint256 netSyIn, uint256 netSyFee, uint256 netSyToReserve) = calcSyIn(a.market, comp, a.index, guess);

            if (netSyIn > a.totalSyIn) {
                a.approx.guessMax = guess - 1;
                guess = calcMidpoint(a.approx);
                continue;
            }

            uint256 syNumerator;
            uint256 ptNumerator;

            {
                uint256 newTotalPt = uint256(a.market.totalPt) - guess;
                uint256 netTotalSy = uint256(a.market.totalSy) + netSyIn - netSyToReserve;

                // it is desired that
                // (netPtFromSwap + netPtHolding) / newTotalPt = netSyRemaining / netTotalSy
                // which is equivalent to
                // (netPtFromSwap + netPtHolding) * netTotalSy = netSyRemaining * newTotalPt

                ptNumerator = (guess + a.netPtHolding) * netTotalSy;
                syNumerator = (a.totalSyIn - netSyIn) * newTotalPt;
            }

            if (PMath.isAApproxB(syNumerator, ptNumerator, a.approx.eps)) {
                return (guess, netSyIn, netSyFee);
            }

            if (ptNumerator <= syNumerator) {
                if (a.approx.guessMin == guess) {
                    break;
                }
                a.approx.guessMin = guess;
            } else {
                a.approx.guessMax = guess - 1;
            }

            if (!quickCalcRan && PMath.isAApproxB(syNumerator, ptNumerator, QUICK_CALC_TRIGGER_EPS)) {
                quickCalcRan = true;
                guess = quickCalc(a, guess, netSyIn, netSyToReserve);
                if (guess <= a.approx.guessMin || guess >= a.approx.guessMax) guess = calcMidpoint(a.approx);
            } else {
                guess = calcMidpoint(a.approx);
            }
        }
        revert("Slippage: APPROX_EXHAUSTED");
    }

    function quickCalc(
        Args6 memory a,
        uint256 _guess,
        uint256 _netSyIn,
        uint256 _netSyToReserve
    ) internal pure returns (uint256) {
        uint256 low = a.approx.guessMin;
        uint256 high = a.approx.guessMax;

        unchecked {
            for (uint256 i = 0; i < QUICK_CALC_MAX_ITER; i++) {
                uint256 mid = (low + high) / 2;
                uint256 newTotalPt = uint256(a.market.totalPt) - mid;

                uint256 thisNetSyIn = (_netSyIn * mid) / _guess;
                uint256 thisNetSyToReserve = (_netSyToReserve * mid) / _guess;

                if (thisNetSyIn > a.totalSyIn) {
                    high = mid - 1;
                    if (low > high) return mid;
                    continue;
                }

                uint256 netTotalSy = uint256(a.market.totalSy) + thisNetSyIn - thisNetSyToReserve;

                uint256 ptNumerator = (mid + a.netPtHolding) * netTotalSy;
                uint256 syNumerator = (a.totalSyIn - thisNetSyIn) * newTotalPt;
                if (isAApproxBUnchecked(syNumerator, ptNumerator, a.approx.eps)) {
                    return mid;
                }

                if (ptNumerator <= syNumerator) {
                    low = mid;
                } else {
                    high = mid - 1;
                }

                if (low > high) return mid;
            }

            return (low + high) / 2;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////

    function calcSyIn(
        MarketState memory market,
        MarketPreCompute memory comp,
        PYIndex index,
        uint256 netPtOut
    ) internal pure returns (uint256 netSyIn, uint256 netSyFee, uint256 netSyToReserve) {
        (int256 _netSyIn, int256 _netSyFee, int256 _netSyToReserve) = market.calcTrade(comp, index, int256(netPtOut));

        // all safe since totalPt and totalSy is int128
        netSyIn = uint256(-_netSyIn);
        netSyFee = uint256(_netSyFee);
        netSyToReserve = uint256(_netSyToReserve);
    }

    function calcMaxPtOut(MarketPreCompute memory comp, int256 totalPt) internal pure returns (uint256) {
        int256 logitP = (comp.feeRate - comp.rateAnchor).mulDown(comp.rateScalar).exp();
        int256 proportion = logitP.divDown(logitP + PMath.IONE);
        int256 numerator = proportion.mulDown(totalPt + comp.totalAsset);
        int256 maxPtOut = totalPt - numerator;
        // only get 99.9% of the theoretical max to accommodate some precision issues
        return (uint256(maxPtOut) * 999) / 1000;
    }

    function validateApprox(ApproxParams memory approx) internal pure {
        if (approx.guessMin > approx.guessMax || approx.eps > PMath.ONE) revert("Internal: INVALID_APPROX_PARAMS");
    }
}

function scaleClamp(
    uint256 original,
    uint256 target,
    uint256 current,
    ApproxParams memory approx
) pure returns (uint256) {
    uint256 scaled = (original * target) / current;
    if (scaled >= approx.guessMax) return calcMidpoint(approx);
    if (scaled <= approx.guessMin) return calcMidpoint(approx);

    return scaled;
}

function getFirstGuess(ApproxParams memory approx) pure returns (uint256) {
    return (approx.guessOffchain != 0) ? approx.guessOffchain : calcMidpoint(approx);
}

function calcMidpoint(ApproxParams memory approx) pure returns (uint256) {
    return (approx.guessMin + approx.guessMax + 1) / 2;
}

function isAApproxBUnchecked(uint256 a, uint256 b, uint256 eps) pure returns (bool) {
    unchecked {
        uint256 bLow = (b * (1e18 - eps)) / 1e18;
        uint256 bHigh = (b * (1e18 + eps)) / 1e18;
        return bLow <= a && a <= bHigh;
    }
}
