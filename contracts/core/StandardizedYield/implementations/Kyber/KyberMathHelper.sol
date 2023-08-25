// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../../../interfaces/Kyber/IKyberElasticPool.sol";
import "../../../../interfaces/Kyber/IKyberElasticFactory.sol";
import "./libraries/ReinvestmentMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/SwapMath.sol";
import "./libraries/LiqDeltaMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/QtyDeltaMath.sol";
import { MathConstants as C } from "./libraries/MathConstants.sol";
import "../../../libraries/math/Math.sol";

import "../../../libraries/BoringOwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract KyberMathHelper is BoringOwnableUpgradeable, UUPSUpgradeable {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeCast for int128;
    using Math for int24;
    using Math for int256;
    using Math for uint256;

    uint256 public constant DEFAULT_NUMBER_OF_ITERS = 20;

    address public immutable factory;

    uint256 numBinarySearchIter = DEFAULT_NUMBER_OF_ITERS;

    constructor(address _factory) {
        factory = IKyberElasticPool(_factory).factory();
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function setNumBinarySearchIter(uint256 newNumBinarySearchIter) external onlyOwner {
        numBinarySearchIter = newNumBinarySearchIter;
    }

    function getSingleSidedSwapAmount(
        address kyberPool,
        uint256 startAmount,
        bool isToken0,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256 amountToSwap) {
        uint256 low = 0;
        uint256 high = startAmount;
        uint160 lowerSqrtP = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 upperSqrtP = TickMath.getSqrtRatioAtTick(tickUpper);

        for (uint256 iter = 0; iter < numBinarySearchIter && low != high; ++iter) {
            uint256 guess;

            // First 2 iterations are reserved for 2 bounds (0) and (startAmount)
            // If either of the bounds satisfies, the loop should ends itself with low != high condition
            if (iter == 0) {
                guess = 0;
            } else if (iter == 1) {
                guess = startAmount;
            } else {
                guess = (low + high) / 2;
            }

            (uint256 amountOut, int24 newTick) = _simulateSwapExactIn(kyberPool, guess, isToken0);

            if (isToken0) {
                if (newTick < tickLower) {
                    high = guess;
                } else if (newTick >= tickUpper) {
                    low = guess;
                } else {
                    uint160 currentSqrtP = TickMath.getSqrtRatioAtTick(newTick);
                    uint128 liq0 = LiquidityMath.getLiquidityFromQty0(
                        currentSqrtP,
                        upperSqrtP,
                        startAmount - guess
                    );
                    uint128 liq1 = LiquidityMath.getLiquidityFromQty1(
                        lowerSqrtP,
                        currentSqrtP,
                        amountOut
                    );
                    if (liq0 < liq1) {
                        high = guess;
                    } else {
                        low = guess;
                    }
                }
            } else {
                if (newTick < tickLower) {
                    low = guess;
                } else if (newTick >= tickUpper) {
                    high = guess;
                } else {
                    uint160 currentSqrtP = TickMath.getSqrtRatioAtTick(newTick);
                    uint128 liq0 = LiquidityMath.getLiquidityFromQty0(
                        currentSqrtP,
                        upperSqrtP,
                        amountOut
                    );
                    uint128 liq1 = LiquidityMath.getLiquidityFromQty1(
                        lowerSqrtP,
                        currentSqrtP,
                        startAmount - guess
                    );
                    if (liq1 < liq0) {
                        high = guess;
                    } else {
                        low = guess;
                    }
                }
            }
        }
        amountToSwap = low;
    }

    // temporary swap variables, some of which will be used to update the pool state
    struct SwapData {
        int256 specifiedAmount; // the specified amount (could be tokenIn or tokenOut)
        int256 returnedAmount; // the opposite amout of sourceQty
        uint160 sqrtP; // current sqrt(price), multiplied by 2^96
        int24 currentTick; // the tick associated with the current price
        int24 nextTick; // the next initialized tick
        uint160 nextSqrtP; // the price of nextTick
        bool isToken0; // true if specifiedAmount is in token0, false if in token1
        bool isExactInput; // true = input qty, false = output qty
        uint128 baseL; // the cached base pool liquidity without reinvestment liquidity
        uint128 reinvestL; // the cached reinvestment liquidity
        uint160 startSqrtP; // the start sqrt price before each iteration
        /// PENDLE additional data
        uint256 feeUnit;
        uint256 reinvestLLast;
    }

    // variables below are loaded only when crossing a tick
    struct SwapCache {
        uint256 rTotalSupply; // cache of total reinvestment token supply
        uint128 reinvestLLast; // collected liquidity
        uint256 feeGrowthGlobal; // cache of fee growth of the reinvestment token, multiplied by 2^96
        uint128 secondsPerLiquidityGlobal; // all-time seconds per liquidity, multiplied by 2^96
        address feeTo; // recipient of govt fees
        uint24 governmentFeeUnits; // governmentFeeUnits to be charged
        uint256 governmentFee; // qty of reinvestment token for government fee
        uint256 lpFee; // qty of reinvestment token for liquidity provider
    }

    function _simulateSwapExactIn(
        address kyberPool,
        uint256 swapQty,
        bool isToken0
    ) internal view returns (uint256 amountOut, int24 newTick) {
        SwapData memory swapData;
        swapData.specifiedAmount = swapQty.Int();
        swapData.isToken0 = isToken0;
        swapData.isExactInput = swapData.specifiedAmount > 0;

        bool willUpTick = (swapData.isExactInput != isToken0);
        uint128 cachedReinvestLLast;
        (
            swapData.baseL,
            swapData.reinvestL,
            swapData.reinvestLLast,
            swapData.sqrtP,
            swapData.currentTick,
            swapData.nextTick,
            swapData.feeUnit
        ) = _getInitialSwapData(kyberPool, willUpTick);

        SwapCache memory cache;
        while (swapData.specifiedAmount != 0) {
            int24 tempNextTick = swapData.nextTick;
            if (willUpTick && tempNextTick > C.MAX_TICK_DISTANCE + swapData.currentTick) {
                tempNextTick = swapData.currentTick + C.MAX_TICK_DISTANCE;
            } else if (!willUpTick && tempNextTick < swapData.currentTick - C.MAX_TICK_DISTANCE) {
                tempNextTick = swapData.currentTick - C.MAX_TICK_DISTANCE;
            }

            swapData.startSqrtP = swapData.sqrtP;
            swapData.nextSqrtP = TickMath.getSqrtRatioAtTick(tempNextTick);

            {
                uint160 targetSqrtP = swapData.nextSqrtP;

                int256 usedAmount;
                int256 returnedAmount;
                uint256 deltaL;
                (usedAmount, returnedAmount, deltaL, swapData.sqrtP) = SwapMath.computeSwapStep(
                    swapData.baseL + swapData.reinvestL,
                    swapData.sqrtP,
                    targetSqrtP,
                    swapData.feeUnit,
                    swapData.specifiedAmount,
                    swapData.isExactInput,
                    swapData.isToken0
                );

                swapData.specifiedAmount -= usedAmount;
                swapData.returnedAmount += returnedAmount;
                swapData.reinvestL += deltaL.toUint128();
            }

            // if price has not reached the next sqrt price
            if (swapData.sqrtP != swapData.nextSqrtP) {
                if (swapData.sqrtP != swapData.startSqrtP) {
                    // update the current tick data in case the sqrtP has changed
                    swapData.currentTick = TickMath.getTickAtSqrtRatio(swapData.sqrtP);
                }
                break;
            }
            swapData.currentTick = willUpTick ? tempNextTick : tempNextTick - 1;

            // if tempNextTick is not next initialized tick
            if (tempNextTick != swapData.nextTick) continue;

            if (cache.rTotalSupply == 0) {
                // load variables that are only initialized when crossing a tick
                cache.rTotalSupply = IKyberElasticPool(kyberPool).totalSupply();
                cache.reinvestLLast = cachedReinvestLLast;
                cache.feeGrowthGlobal = IKyberElasticPool(kyberPool).getFeeGrowthGlobal();

                // not sure if this is necessary for the amount out & current tick computation
                // let's ignore for now
                // cache.secondsPerLiquidityGlobal = _syncSecondsPerLiquidity(
                //     poolData.secondsPerLiquidityGlobal,
                //     swapData.baseL
                // );
                (cache.feeTo, cache.governmentFeeUnits) = IKyberElasticFactory(factory)
                    .feeConfiguration();
            }

            // update rTotalSupply, feeGrowthGlobal and reinvestL
            uint256 rMintQty = ReinvestmentMath.calcrMintQty(
                swapData.reinvestL,
                cache.reinvestLLast,
                swapData.baseL,
                cache.rTotalSupply
            );

            if (rMintQty != 0) {
                cache.rTotalSupply += rMintQty;
                // overflow/underflow not possible bc governmentFeeUnits < 20000
                unchecked {
                    uint256 governmentFee = (rMintQty * cache.governmentFeeUnits) / C.FEE_UNITS;
                    cache.governmentFee += governmentFee;

                    uint256 lpFee = rMintQty - governmentFee;
                    cache.lpFee += lpFee;

                    cache.feeGrowthGlobal += FullMath.mulDivFloor(
                        lpFee,
                        C.TWO_POW_96,
                        swapData.baseL
                    );
                }
            }
            cache.reinvestLLast = swapData.reinvestL;

            (swapData.baseL, swapData.nextTick) = _updateLiquidityAndCrossTick(
                kyberPool,
                swapData.nextTick,
                swapData.baseL,
                cache.feeGrowthGlobal,
                cache.secondsPerLiquidityGlobal,
                willUpTick
            );
        }

        amountOut = swapData.returnedAmount.abs();
        newTick = swapData.currentTick;
    }

    function _updateLiquidityAndCrossTick(
        address kyberPool,
        int24 nextTick,
        uint128 currentLiquidity,
        uint256,
        uint128,
        bool willUpTick
    ) internal view returns (uint128 newLiquidity, int24 newNextTick) {
        (, int128 liquidityNet, , ) = IKyberElasticPool(kyberPool).ticks(nextTick);
        if (willUpTick) {
            (, newNextTick) = IKyberElasticPool(kyberPool).initializedTicks(nextTick);
        } else {
            (newNextTick, ) = IKyberElasticPool(kyberPool).initializedTicks(nextTick);
            liquidityNet = -liquidityNet;
        }
        newLiquidity = LiqDeltaMath.applyLiquidityDelta(
            currentLiquidity,
            liquidityNet >= 0 ? uint128(liquidityNet) : liquidityNet.revToUint128(),
            liquidityNet >= 0
        );
    }

    function _getInitialSwapData(
        address kyberPool,
        bool willUpTick
    )
        internal
        view
        returns (
            uint128 baseL,
            uint128 reinvestL,
            uint128 reinvestLLast,
            uint160 sqrtP,
            int24 currentTick,
            int24 nextTick,
            uint256 feeUnit
        )
    {
        (baseL, reinvestL, reinvestLLast) = IKyberElasticPool(kyberPool).getLiquidityState();
        (sqrtP, currentTick, nextTick, ) = IKyberElasticPool(kyberPool).getPoolState();
        if (willUpTick) {
            (, nextTick) = IKyberElasticPool(kyberPool).initializedTicks(nextTick);
        }
        feeUnit = IKyberElasticPool(kyberPool).swapFeeUnits();
    }
}
