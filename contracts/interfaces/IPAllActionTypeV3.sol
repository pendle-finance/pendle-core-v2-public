// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "../router/swap-aggregator/IPSwapAggregator.sol";
import "./IPLimitRouter.sol";

/*
 *******************************************************************************************************************
 *******************************************************************************************************************
 * NOTICE *
 * Refer to https://docs.pendle.finance/Developers/Contracts/PendleRouter for more information on
 * TokenInput, TokenOutput, ApproxParams, LimitOrderData
 * It's recommended to use Pendle's Hosted SDK to generate the params
 *******************************************************************************************************************
 *******************************************************************************************************************
 */

function createSwapTypeNoAggregator() pure returns (SwapData memory) {}

struct TokenInput {
    // TOKEN DATA
    address tokenIn;
    uint256 netTokenIn;
    address tokenMintSy;
    // AGGREGATOR DATA
    address pendleSwap;
    SwapData swapData;
}

/// Utility to generate `TokenInput` struct for simple swapping,
/// from one of the SY's token in, that does not invole external aggregator.
/// @param tokenIn SY token in. Can be obtained via `IStandardizedYield#getTokensIn`
/// @param netTokenIn amount of token in.
function createTokenInputSimple(address tokenIn, uint256 netTokenIn) pure returns (TokenInput memory) {
    return
        TokenInput({
            tokenIn: tokenIn,
            netTokenIn: netTokenIn,
            tokenMintSy: tokenIn,
            pendleSwap: address(0),
            swapData: createSwapTypeNoAggregator()
        });
}

struct TokenOutput {
    // TOKEN DATA
    address tokenOut;
    uint256 minTokenOut;
    address tokenRedeemSy;
    // AGGREGATOR DATA
    address pendleSwap;
    SwapData swapData;
}

/// Utility to generate `TokenOutput` struct for simple swapping,
/// to one of the SY's token in that does not invole external aggregator.
/// @param tokenOut SY token out. Can be obtained via `IStandardizedYield#getTokensOut`
/// @param minTokenOut minimum
function createTokenOutputSimple(address tokenOut, uint256 minTokenOut) pure returns (TokenOutput memory) {
    return
        TokenOutput({
            tokenOut: tokenOut,
            minTokenOut: minTokenOut,
            tokenRedeemSy: tokenOut,
            pendleSwap: address(0),
            swapData: createSwapTypeNoAggregator()
        });
}

struct LimitOrderData {
    address limitRouter;
    uint256 epsSkipMarket; // only used for swap operations, will be ignored otherwise
    FillOrderParams[] normalFills;
    FillOrderParams[] flashFills;
    bytes optData;
}

/// Utility to generate `LimitOrderData` that does not involve Pendle limit
/// order.
function createEmptyLimitOrderData() pure returns (LimitOrderData memory) {}

/// @dev For guessOffchain, this is to provide a shortcut to guessing. The offchain SDK can precalculate the exact result
/// before the tx is sent. When the tx reaches the contract, the guessOffchain will be checked first, and if it satisfies the
/// approximation, it will be used (and save all the guessing). It's expected that this shortcut will be used in most cases
/// except in cases that there is a trade in the same market right before the tx.
/// If 0 is passed to guessOffchain, the on-chain approximation algorithm will be executed.
///
/// @dev eos is the max eps between the returned result & the correct result, base 1e18.
/// Normally this number will be set to 1e15 (1e18/1000 = 0.1%)
struct ApproxParams {
    uint256 guessMin;
    uint256 guessMax;
    uint256 guessOffchain;
    uint256 maxIteration;
    uint256 eps;
}

/// Utility to generate ApproxParams that will enable on-chain approximation.
/// @notice Please refer to `./IPActionSimple.sol` for the set of simpler functions,
/// with stripped down parameters and builtin on-chain approximation.
function createDefaultApproxParams() pure returns (ApproxParams memory) {
    return ApproxParams({guessMin: 0, guessMax: type(uint256).max, guessOffchain: 0, maxIteration: 256, eps: 1e15});
}

struct ExitPreExpReturnParams {
    uint256 netPtFromRemove;
    uint256 netSyFromRemove;
    uint256 netPyRedeem;
    uint256 netSyFromRedeem;
    uint256 netPtSwap;
    uint256 netYtSwap;
    uint256 netSyFromSwap;
    uint256 netSyFee;
    uint256 totalSyOut;
}

struct ExitPostExpReturnParams {
    uint256 netPtFromRemove;
    uint256 netSyFromRemove;
    uint256 netPtRedeem;
    uint256 netSyFromRedeem;
    uint256 totalSyOut;
}
