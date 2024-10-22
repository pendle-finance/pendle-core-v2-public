// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ApproxParams} from "../../interfaces/IPAllActionTypeV3.sol";
import {PMath} from "../../core/libraries/math/PMath.sol";

enum ApproxStage {
    INITIAL,
    RANGE_SEARCHING,
    RESULT_FINDING
}

struct ApproxState {
    ApproxStage stage;
    uint256 maxIteration;
    uint256 eps;
    uint256 startingGuess;
    uint256 curGuess;
    /// Defines the range that constrains the result.
    /// This range will be dynamically adjusted if the result falls outside of it.
    uint256[2] ranges;
    /// Specifies the range within which the result must fall.
    /// Any value outside this range is considered invalid.
    uint256[2] hardBounds;
}

using ApproxStateLib for ApproxState global;

/// A library for determining the next guess from the current / `ApproxState`
/// state, dynamically adjusting the search range to fit the valid / result
/// range.
///
/// @dev Invariants to maintain:
/// - state.hardBounds should always include state.ranges
/// - state.ranges should always include state.curGuess
/// That is:
///     state.hardBounds[0] <= state.ranges[0] <= state.curGuess <= state.ranges[1] <= state.hardBounds[1]
library ApproxStateLib {
    using PMath for uint256;
    using ApproxStateLib for ApproxState;

    uint256 internal constant GUESS_RANGE_TWEAK = (5 * PMath.ONE) / 100;

    uint256 internal constant DEFAULT_MAX_ITERATION = 30;
    uint256 internal constant DEFAULT_EPS = 5e13;

    function initWithOffchain(ApproxParams memory approx) internal pure returns (ApproxState memory) {
        if (approx.guessMin > approx.guessOffchain || approx.guessOffchain > approx.guessMax || approx.eps > PMath.ONE)
            revert("Internal: INVALID_APPROX_PARAMS");
        return
            ApproxState({
                stage: ApproxStage.RESULT_FINDING,
                ranges: [approx.guessMin, approx.guessMax],
                hardBounds: [approx.guessMin, approx.guessMax],
                curGuess: approx.guessOffchain,
                startingGuess: approx.guessOffchain,
                maxIteration: approx.maxIteration,
                eps: approx.eps
            });
    }

    function initNoOffChain(
        uint256 estimation,
        uint256[2] memory hardBounds
    ) internal pure returns (ApproxState memory) {
        assert(hardBounds[0] <= hardBounds[1]);

        uint256 startingGuess = PMath.clamp(estimation, hardBounds[0], hardBounds[1]);
        uint256 rangesLower = PMath.max(startingGuess.tweakDown(GUESS_RANGE_TWEAK), hardBounds[0]);
        uint256 rangesUpper = PMath.min(startingGuess.tweakUp(GUESS_RANGE_TWEAK), hardBounds[1]);
        return
            ApproxState({
                stage: ApproxStage.INITIAL,
                ranges: [rangesLower, rangesUpper],
                hardBounds: hardBounds,
                curGuess: startingGuess,
                startingGuess: startingGuess,
                maxIteration: DEFAULT_MAX_ITERATION,
                eps: DEFAULT_EPS
            });
    }

    function transitionDown(ApproxState memory state, bool excludeGuessFromRange) internal pure {
        state.ranges[1] = state.curGuess;
        if (excludeGuessFromRange) state.ranges[1]--;

        if (state.stage == ApproxStage.INITIAL) {
            state.stage = ApproxStage.RANGE_SEARCHING;
            state.curGuess = state.ranges[0];
        } else if (state.stage == ApproxStage.RANGE_SEARCHING) {
            if (state.curGuess == state.hardBounds[0]) revert("Slippage: search range underflow");

            bool shouldExtend = state.curGuess == state.ranges[0];
            if (!shouldExtend) {
                state.stage = ApproxStage.RESULT_FINDING;
                moveGuessToMiddle(state);
                return;
            }
            uint256 distToStartingGuess = state.startingGuess - state.ranges[0];
            uint256 extendedLower = PMath.subWithLowerBound(state.ranges[0], distToStartingGuess, state.hardBounds[0]);
            state.ranges[0] = extendedLower;
            state.curGuess = extendedLower;
        } else if (state.stage == ApproxStage.RESULT_FINDING) {
            moveGuessToMiddle(state);
        } else {
            assert(false);
        }
    }

    function transitionUp(ApproxState memory state, bool excludeGuessFromRange) internal pure {
        state.ranges[0] = state.curGuess;
        if (excludeGuessFromRange) state.ranges[0]++;

        if (state.stage == ApproxStage.INITIAL) {
            state.stage = ApproxStage.RANGE_SEARCHING;
            state.curGuess = state.ranges[1];
        } else if (state.stage == ApproxStage.RANGE_SEARCHING) {
            if (state.curGuess == state.hardBounds[1]) revert("Slippage: search range overflow");

            bool shouldExtend = state.curGuess == state.ranges[1];
            if (!shouldExtend) {
                state.stage = ApproxStage.RESULT_FINDING;
                moveGuessToMiddle(state);
                return;
            }
            uint256 distFromStartingGuess = state.ranges[1] - state.startingGuess;
            uint256 extendedUpper = (
                PMath.addWithUpperBound(state.ranges[1], distFromStartingGuess, state.hardBounds[1])
            );
            state.ranges[1] = extendedUpper;
            state.curGuess = extendedUpper;
        } else if (state.stage == ApproxStage.RESULT_FINDING) {
            moveGuessToMiddle(state);
        } else {
            assert(false);
        }
    }

    function moveGuessToMiddle(ApproxState memory state) internal pure {
        if (state.ranges[0] > state.ranges[1]) revert("Slippage: guessMin > guessMax");
        state.curGuess = (state.ranges[0] + state.ranges[1]) / 2;
    }
}
