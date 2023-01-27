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

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../core/libraries/TokenHelper.sol";
import "./IAggregatorRouterHelper.sol";
import "../../core/libraries/Errors.sol";

struct TokenInput {
    // Token/Sy data
    address tokenIn;
    uint256 netTokenIn;
    address tokenMintSy;
    address bulk;
    // Kyber data
    address kyberRouter;
    bytes kybercall;
}

struct TokenOutput {
    // Token/Sy data
    address tokenOut;
    uint256 minTokenOut;
    address tokenRedeemSy;
    address bulk;
    // Kyber data
    address kyberRouter;
    bytes kybercall;
}

abstract contract KyberSwapHelper is TokenHelper {
    using Address for address;

    address public immutable kyberScalingLib;

    constructor(address _kyberScalingLib) {
        kyberScalingLib = _kyberScalingLib;
    }

    function _kyberswap(
        address tokenIn,
        uint256 amountIn,
        address kyberRouter,
        bytes memory rawKybercall
    ) internal {
        if (kyberRouter == address(0) || rawKybercall.length == 0)
            revert Errors.RouterKyberSwapDataZero();

        bytes memory kybercall = IAggregationRouterHelper(kyberScalingLib).getScaledInputData(
            rawKybercall,
            amountIn
        );
        kyberRouter.functionCallWithValue(kybercall, tokenIn == NATIVE ? amountIn : 0);
    }
}
