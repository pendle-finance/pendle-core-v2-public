// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * MIT License
 * ===========
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 */

pragma solidity 0.8.13;
import "../../interfaces/IJoeRouter01.sol";
import "./JoeLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract PendleJoeSwapHelperUpg {
    using SafeERC20 for IERC20;
    address public immutable joeRouter;
    address public immutable joeFactory;

    /// @dev since this contract will be proxied, it must not contains non-immutable variables
    constructor(address _joeRouter, address _joeFactory) {
        joeRouter = _joeRouter;
        joeFactory = _joeFactory;
    }

    /**
     * @notice swap tokens with no limit on amountOut. Tokens must have been transferred to the first pair
     */
    function _swapExactIn(
        address[] memory path,
        uint256 amountIn,
        address receiver
    ) internal virtual returns (uint256 amountOut) {
        uint256[] memory amounts = JoeLibrary.getAmountsOut(joeFactory, amountIn, path);
        _low_level_swap(amounts, path, receiver);
        amountOut = amounts[amounts.length - 1];
    }

    /// function from TraderJoe
    function _low_level_swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = JoeLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? JoeLibrary.pairFor(joeFactory, output, path[i + 2])
                : _to;
            IJoePair(JoeLibrary.pairFor(joeFactory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function _getFirstPair(address[] memory path) internal view returns (address pair) {
        return JoeLibrary.pairFor(joeFactory, path[0], path[1]);
    }
}
