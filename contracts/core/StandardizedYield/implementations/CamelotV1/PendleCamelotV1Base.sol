// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "../../../../interfaces/Camelot/ICamelotPair.sol";
import "../../../../interfaces/Camelot/ICamelotRouter.sol";
import "../../../../interfaces/Camelot/ICamelotFactory.sol";
import "../../../libraries/TokenHelper.sol";
import "../../../libraries/math/Math.sol";

/**
 * @notice This contract is intended to be launched on Arbitrum
 *         Thus, some obvious gas optimization might be ignored
 *
 * @notice Since Camelot LP offers PENDLE as a reward token,
 * this contract should not take into account any floating balance
 * for swap/add liquidity
 */

abstract contract PendleCamelotV1Base is TokenHelper {
    struct CamelotPairData {
        uint256 reserve0;
        uint256 reserve1;
        uint256 fee0;
        uint256 fee1;
    }

    address public immutable token0;
    address public immutable token1;
    address public immutable pair;
    address public immutable factory;
    address public immutable router;
    uint256 private constant FEE_DENOMINATOR = 100000;
    uint256 private constant ONE = 1 * FEE_DENOMINATOR;
    uint256 private constant TWO = 2 * FEE_DENOMINATOR;
    uint256 private constant FOUR = 4 * FEE_DENOMINATOR;

    constructor(address _pair, address _factory, address _router) {
        pair = _pair;
        factory = _factory;
        router = _router;
        token0 = ICamelotPair(pair).token0();
        token1 = ICamelotPair(pair).token1();

        _safeApproveInf(token0, router);
        _safeApproveInf(token1, router);
        _safeApproveInf(pair, router);
    }

    /**
     * ==================================================================
     *                      ZAP ACTION RELATED
     * ==================================================================
     */
    function _zapIn(address tokenIn, uint256 amountIn) internal returns (uint256) {
        (uint256 amount0ToAddLiq, uint256 amount1ToAddLiq) = _swapZapIn(tokenIn, amountIn);
        return _addLiquidity(amount0ToAddLiq, amount1ToAddLiq);
    }

    function _zapOut(address tokenOut, uint256 amountLpIn) internal returns (uint256) {
        (uint256 amount0, uint256 amount1) = _removeLiquidity(amountLpIn);
        if (tokenOut == token0) {
            return amount0 + _swap(token1, amount1);
        } else {
            return amount1 + _swap(token0, amount0);
        }
    }

    function _swapZapIn(
        address tokenIn,
        uint256 amountIn
    ) private returns (uint256 amount0ToAddLiq, uint256 amount1ToAddLiq) {
        (uint256 reserveA, uint256 reserveB, uint256 feeA, uint256 feeB) = ICamelotPair(pair)
            .getReserves();

        if (tokenIn == token0) {
            uint256 amount0ToSwap = _getZapInSwapAmount(amountIn, reserveA, feeA);
            amount0ToAddLiq = amountIn - amount0ToSwap;
            amount1ToAddLiq = _swap(token0, amount0ToSwap);
        } else {
            uint256 amount1ToSwap = _getZapInSwapAmount(amountIn, reserveB, feeB);
            amount0ToAddLiq = _swap(token1, amount1ToSwap);
            amount1ToAddLiq = amountIn - amount1ToSwap;
        }
    }

    /**
     * ==================================================================
     *                      CAMELOT ROUTER RELATED
     * ==================================================================
     */

    function _addLiquidity(
        uint256 amount0ToAddLiq,
        uint256 amount1ToAddLiq
    ) private returns (uint256 amountLpOut) {
        (, , amountLpOut) = ICamelotRouter(router).addLiquidity(
            token0,
            token1,
            amount0ToAddLiq,
            amount1ToAddLiq,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function _removeLiquidity(
        uint256 amountLpToRemove
    ) private returns (uint256 amountTokenA, uint256 amountTokenB) {
        return
            ICamelotRouter(router).removeLiquidity(
                token0,
                token1,
                amountLpToRemove,
                0,
                0,
                address(this),
                block.timestamp
            );
    }

    function _swap(address tokenIn, uint256 amountTokenIn) private returns (uint256) {
        address[] memory path = new address[](2);

        address tokenOut = tokenIn == token0 ? token1 : token0;

        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256 preBalance = _selfBalance(tokenOut);

        ICamelotRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountTokenIn,
            0,
            path,
            address(this),
            address(0),
            block.timestamp
        );

        return _selfBalance(tokenOut) - preBalance;
    }

    /**
     * ==================================================================
     *                              MATH
     * ==================================================================
     */

    // reference: https://blog.alphaventuredao.io/onesideduniswap/
    function _getZapInSwapAmount(
        uint256 amountIn,
        uint256 reserve,
        uint256 fee
    ) private pure returns (uint256) {
        return
            (sqrt(sqr((TWO - fee) * reserve) + FOUR * (ONE - fee) * amountIn * reserve) -
                (TWO - fee) *
                reserve) / (2 * (ONE - fee));
    }

    // reference: https://github.com/Uniswap/v2-core/blob/master/contracts/libraries/Math.sol
    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function sqr(uint256 x) internal pure returns (uint256) {
        return x * x;
    }

    /**
     * ==================================================================
     *                              PREVIEW
     * ==================================================================
     */

    /**
     * @notice The Camelot.swap() function takes reserve() as the previously recorded at the start
     * and take into account ALL floating balances after.
     */
    function _previewZapIn(
        address tokenIn,
        uint256 amountTokenIn
    ) internal view returns (uint256 amountLpOut) {
        CamelotPairData memory data;
        (data.reserve0, data.reserve1, data.fee0, data.fee1) = ICamelotPair(pair).getReserves();

        bool isToken0 = tokenIn == token0;

        uint256 amountToSwap = isToken0
            ? _getZapInSwapAmount(amountTokenIn, data.reserve0, data.fee0)
            : _getZapInSwapAmount(amountTokenIn, data.reserve1, data.fee1);

        uint256 amountSwapOut = _getSwapAmountOut(
            amountToSwap,
            tokenIn,
            data.reserve0,
            data.reserve1,
            tokenIn == token0 ? data.fee0 : data.fee1
        );

        uint256 amount0ToAddLiq;
        uint256 amount1ToAddLiq;

        if (isToken0) {
            data.reserve0 = _getPairBalance0() + amountToSwap;
            data.reserve1 = _getPairBalance1() - amountSwapOut;

            amount0ToAddLiq = amountTokenIn - amountToSwap;
            amount1ToAddLiq = amountSwapOut;
        } else {
            data.reserve0 = _getPairBalance0() - amountSwapOut;
            data.reserve1 = _getPairBalance1() + amountToSwap;

            amount0ToAddLiq = amountSwapOut;
            amount1ToAddLiq = amountTokenIn - amountToSwap;
        }

        return _calcAmountLpOut(data, amount0ToAddLiq, amount1ToAddLiq);
    }

    function _previewZapOut(address tokenOut, uint256 amountLpIn) internal view returns (uint256) {
        CamelotPairData memory data;
        (data.reserve0, data.reserve1, data.fee0, data.fee1) = ICamelotPair(pair).getReserves();

        uint256 totalSupply = _getTotalSupplyAfterMintFee(data);

        data.reserve0 = _getPairBalance0();
        data.reserve1 = _getPairBalance1();

        uint256 amount0Removed = (data.reserve0 * amountLpIn) / totalSupply;
        uint256 amount1Removed = (data.reserve1 * amountLpIn) / totalSupply;

        data.reserve0 -= amount0Removed;
        data.reserve1 -= amount1Removed;

        if (tokenOut == token0) {
            return
                amount0Removed +
                _getSwapAmountOut(amount1Removed, token1, data.reserve0, data.reserve1, data.fee1);
        } else {
            return
                amount1Removed +
                _getSwapAmountOut(amount0Removed, token0, data.reserve0, data.reserve1, data.fee0);
        }
    }

    function _getPairBalance0() private view returns (uint256) {
        return IERC20(token0).balanceOf(pair);
    }

    function _getPairBalance1() private view returns (uint256) {
        return IERC20(token1).balanceOf(pair);
    }

    // @reference: Camelot
    function _getSwapAmountOut(
        uint256 amountIn,
        address tokenIn,
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 feePercent
    ) internal view returns (uint256) {
        (uint256 reserve0, uint256 reserve1) = tokenIn == token0
            ? (_reserve0, _reserve1)
            : (_reserve1, _reserve0);
        amountIn = amountIn * (FEE_DENOMINATOR - feePercent);
        return (amountIn * reserve1) / (reserve0 * FEE_DENOMINATOR + amountIn);
    }

    /**
     * @notice This function simulates Camelot router so any precision issues from their calculation
     * is preserved in preview functions...
     */
    function _calcAmountLpOut(
        CamelotPairData memory data,
        uint256 amount0ToAddLiq,
        uint256 amount1ToAddLiq
    ) private view returns (uint256 amountLpOut) {
        uint256 amount1Optimal = _quote(amount0ToAddLiq, data.reserve0, data.reserve1);
        if (amount1Optimal <= amount1ToAddLiq) {
            amount1ToAddLiq = amount1Optimal;
        } else {
            amount0ToAddLiq = _quote(amount1ToAddLiq, data.reserve1, data.reserve0);
        }

        uint256 supply = _getTotalSupplyAfterMintFee(data);
        return
            Math.min(
                (amount0ToAddLiq * supply) / data.reserve0,
                (amount1ToAddLiq * supply) / data.reserve1
            );
    }

    function _quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) private pure returns (uint amountB) {
        amountB = (amountA * reserveB) / reserveA;
    }

    function _getTotalSupplyAfterMintFee(
        CamelotPairData memory data
    ) private view returns (uint256) {
        (uint256 ownerFeeShare, address feeTo) = ICamelotFactory(factory).feeInfo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = ICamelotPair(pair).kLast();

        uint256 totalSupply = ICamelotPair(pair).totalSupply();
        // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = sqrt(data.reserve0 * data.reserve1);
                uint256 rootKLast = sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 d = (FEE_DENOMINATOR * 100) / ownerFeeShare - 100;
                    uint256 numerator = totalSupply * (rootK - rootKLast) * 100;
                    uint256 denominator = rootK * d + rootKLast * 100;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) {
                        totalSupply += liquidity;
                    }
                }
            }
        }
        return totalSupply;
    }
}
