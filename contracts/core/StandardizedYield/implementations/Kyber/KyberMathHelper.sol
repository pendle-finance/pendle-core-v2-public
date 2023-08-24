// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../../../../interfaces/Kyber/IKyberElasticPool.sol";
import "../../../../interfaces/Kyber/IKyberElasticFactory.sol";
import "./libraries/ReinvestmentMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/SwapMath.sol";
import "./libraries/LiqDeltaMath.sol";
import { MathConstants as C } from "./libraries/MathConstants.sol";
import "../../../libraries/math/Math.sol";

abstract contract KyberMathHelper {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeCast for int128;
    using Math for int24;

    address public immutable factory;
    address public immutable kyberPool;
    uint24 public immutable swapFeeUnits;

    constructor(address _kyberPool) {
        kyberPool = _kyberPool;
        factory = IKyberElasticPool(_kyberPool).factory();
        swapFeeUnits = IKyberElasticPool(_kyberPool).swapFeeUnits();
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

    function _simulateSwap(
        int256 swapQty,
        bool isToken0
    ) internal view returns (int deltaQty0, int deltaQty1, int24 newTick) {
        require(swapQty != 0, "0 swapQty");

        SwapData memory swapData;
        swapData.specifiedAmount = swapQty;
        swapData.isToken0 = isToken0;
        swapData.isExactInput = swapData.specifiedAmount > 0;

        bool willUpTick = (swapData.isExactInput != isToken0);
        uint128 cachedReinvestLLast;
        (
            swapData.baseL,
            swapData.reinvestL,
            cachedReinvestLLast,
            swapData.sqrtP,
            swapData.currentTick,
            swapData.nextTick
        ) = _getInitialSwapData(willUpTick);

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
                    swapFeeUnits,
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
                swapData.nextTick,
                swapData.baseL,
                cache.feeGrowthGlobal,
                cache.secondsPerLiquidityGlobal,
                willUpTick
            );
        }

        (deltaQty0, deltaQty1) = isToken0
            ? (swapQty - swapData.specifiedAmount, swapData.returnedAmount)
            : (swapData.returnedAmount, swapQty - swapData.specifiedAmount);
        newTick = swapData.currentTick;
    }

    function _updateLiquidityAndCrossTick(
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
            int24 nextTick
        )
    {
        (baseL, reinvestL, reinvestLLast) = IKyberElasticPool(kyberPool).getLiquidityState();
        (sqrtP, currentTick, nextTick, ) = IKyberElasticPool(kyberPool).getPoolState();
        if (willUpTick) {
            (, nextTick) = IKyberElasticPool(kyberPool).initializedTicks(nextTick);
        }
    }
}
