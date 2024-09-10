// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ApproxParams} from "./ApproxParams.sol";
import {PMath} from "../../core/libraries/math/PMath.sol";

enum ApproxStage {
    INITIAL,
    RANGE_SEARCHING,
    RESULT_FINDING
}

struct ApproxState {
    ApproxStage stage;
    uint256[2] searchBound;
    ApproxParams approx;
    uint256 curGuess;
}

using ApproxStateLib for ApproxState global;

/// A small library for determining the next guess from the current
/// `ApproxParams` state, dynamically adjusting the search range to fit the valid
/// result range.
library ApproxStateLib {
    using PMath for uint256;

    uint256 internal constant GUESS_RANGE_SLIP = (5 * PMath.ONE) / 100;

    function initWithOffchainGuess(ApproxState memory state, ApproxParams memory approx) internal pure {
        state.stage = ApproxStage.RESULT_FINDING;
        state.searchBound = [0, type(uint256).max];
        state.setApproxParams(approx);
    }

    function initWithoutOffchainGuess(
        ApproxState memory state,
        uint256 estimation,
        uint256[2] memory searchBound,
        ApproxParams memory approx
    ) internal pure {
        state.stage = ApproxStage.INITIAL;
        state.searchBound = searchBound;

        estimation = clampEstimation(state, estimation);
        approx.guessOffchain = estimation;
        approx.guessMin = PMath.max(approx.guessMin, estimation.slipDown(GUESS_RANGE_SLIP));
        approx.guessMax = PMath.min(approx.guessMax, estimation.slipUp(GUESS_RANGE_SLIP));

        state.setApproxParams(approx);
    }

    function tightenApproxBound(ApproxState memory state, ApproxParams memory approx) internal pure {
        uint256 lower = state.searchBound[0];
        uint256 upper = state.searchBound[1];
        if (approx.guessMax < lower || approx.guessMin > upper) {
            revert("Slippage: approx range outside of valid search range");
        }
        if (approx.guessMin < lower) approx.guessMin = lower;
        if (approx.guessMax > upper) approx.guessMax = upper;
    }

    function clampEstimation(ApproxState memory state, uint256 estimation) internal pure returns (uint256) {
        uint256 lower = state.searchBound[0];
        uint256 upper = state.searchBound[1];
        if (estimation < lower) estimation = lower;
        if (estimation > upper) estimation = upper;
        return estimation;
    }

    function setApproxParams(ApproxState memory state, ApproxParams memory approx) internal pure {
        tightenApproxBound(state, approx);
        state.approx = approx;
        state.curGuess = state.approx.guessOffchain;
    }

    function transitionDown(
        ApproxStage stage,
        uint256[2] memory searchBound,
        uint256 guess,
        uint256 guessMin,
        uint256 guessMax,
        uint256 guessOffchain,
        bool excludeGuessFromRange
    ) internal pure returns (ApproxStage nextStage, uint256 nextGuess, uint256 nextGuessMin, uint256 nextGuessMax) {
        nextGuessMax = guess;
        if (excludeGuessFromRange) nextGuessMax--;

        if (stage == ApproxStage.INITIAL) {
            nextStage = ApproxStage.RANGE_SEARCHING;
            nextGuess = nextGuessMin = guessMin;
        } else if (stage == ApproxStage.RANGE_SEARCHING) {
            uint256 LOWER_SEARCH_BOUND = searchBound[0];
            if (guess == LOWER_SEARCH_BOUND) revert("Slippage: search range underflow");

            bool SHOULD_EXTEND_MORE = guess == guessMin;
            if (!SHOULD_EXTEND_MORE) {
                return
                    transitionDown(
                        ApproxStage.RESULT_FINDING,
                        searchBound,
                        guess,
                        guessMin,
                        guessMax,
                        guessOffchain,
                        excludeGuessFromRange
                    );
            }
            nextStage = ApproxStage.RANGE_SEARCHING;
            // change guessMin to double the distance from it to guessOffchain
            nextGuess = nextGuessMin = PMath.subWithLowerBound(guessMin, guessOffchain - guessMin, LOWER_SEARCH_BOUND);
        } else if (stage == ApproxStage.RESULT_FINDING) {
            if (guessMin > guessMax) revert("Slippage: guessMin > guessMax");
            nextStage = ApproxStage.RESULT_FINDING;
            nextGuessMin = guessMin;
            nextGuess = (nextGuessMin + nextGuessMax) / 2;
        } else {
            assert(false);
        }
    }

    function transitionUp(
        ApproxStage stage,
        uint256[2] memory searchBound,
        uint256 guess,
        uint256 guessMin,
        uint256 guessMax,
        uint256 guessOffchain,
        bool excludeGuessFromRange
    ) internal pure returns (ApproxStage nextStage, uint256 nextGuess, uint256 nextGuessMin, uint256 nextGuessMax) {
        nextGuessMin = guess;
        if (excludeGuessFromRange) nextGuessMin++;

        if (stage == ApproxStage.INITIAL) {
            nextStage = ApproxStage.RANGE_SEARCHING;
            nextGuess = nextGuessMax = guessMax;
        } else if (stage == ApproxStage.RANGE_SEARCHING) {
            uint256 UPPER_SEARCH_BOUND = searchBound[1];
            if (guess == UPPER_SEARCH_BOUND) revert("Slippage: search range overflow");

            bool SHOULD_EXTEND_MORE = guess == guessMax;
            if (!SHOULD_EXTEND_MORE) {
                return
                    transitionUp(
                        ApproxStage.RESULT_FINDING,
                        searchBound,
                        guess,
                        guessMin,
                        guessMax,
                        guessOffchain,
                        excludeGuessFromRange
                    );
            }
            nextStage = ApproxStage.RANGE_SEARCHING;
            // change guessMax to double the distance from guessOffchain to it
            nextGuess = nextGuessMax = PMath.addWithUpperBound(guessMax, guessMax - guessOffchain, UPPER_SEARCH_BOUND);
        } else if (stage == ApproxStage.RESULT_FINDING) {
            if (guessMin > guessMax) revert("Slippage: guessMin > guessMax");
            nextStage = ApproxStage.RESULT_FINDING;
            nextGuessMax = guessMax;
            nextGuess = (nextGuessMin + nextGuessMax) / 2;
        } else {
            assert(false);
        }
    }

    function advanceDown(ApproxState memory state, bool excludeGuessFromRange) internal pure {
        (state.stage, state.curGuess, state.approx.guessMin, state.approx.guessMax) = transitionDown(
            state.stage,
            state.searchBound,
            state.curGuess,
            state.approx.guessMin,
            state.approx.guessMax,
            state.approx.guessOffchain,
            excludeGuessFromRange
        );
    }

    function advanceUp(ApproxState memory state, bool excludeGuessFromRange) internal pure {
        (state.stage, state.curGuess, state.approx.guessMin, state.approx.guessMax) = transitionUp(
            state.stage,
            state.searchBound,
            state.curGuess,
            state.approx.guessMin,
            state.approx.guessMax,
            state.approx.guessOffchain,
            excludeGuessFromRange
        );
    }
}
