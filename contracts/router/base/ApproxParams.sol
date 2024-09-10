// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

struct ApproxParams {
    uint256 guessMin;
    uint256 guessMax;
    uint256 guessOffchain; // pass 0 in to skip this variable
    uint256 maxIteration; // every iteration, the diff between guessMin and guessMax will be divided by 2
    uint256 eps; // the max eps between the returned result & the correct result, base 1e18. Normally this number will be set
    // to 1e15 (1e18/1000 = 0.1%)
}

/// Further explanation of the eps. Take swapExactSyForPt for example. To calc the corresponding amount of Pt to swap out,
/// it's necessary to run an approximation algorithm, because by default there only exists the Pt to Sy formula
/// To approx, the 5 values above will have to be provided, and the approx process will run as follows:
/// mid = (guessMin + guessMax) / 2 // mid here is the current guess of the amount of Pt out
/// netSyNeed = calcSwapSyForExactPt(mid)
/// if (netSyNeed > exactSyIn) guessMax = mid - 1 // since the maximum Sy in can't exceed the exactSyIn
/// else guessMin = mid (1)
/// For the (1), since netSyNeed <= exactSyIn, the result might be usable. If the netSyNeed is within eps of
/// exactSyIn (ex eps=0.1% => we have used 99.9% the amount of Sy specified), mid will be chosen as the final guess result

/// for guessOffchain, this is to provide a shortcut to guessing. The offchain SDK can precalculate the exact result
/// before the tx is sent. When the tx reaches the contract, the guessOffchain will be checked first, and if it satisfies the
/// approximation, it will be used (and save all the guessing). It's expected that this shortcut will be used in most cases
/// except in cases that there is a trade in the same market right before the tx
