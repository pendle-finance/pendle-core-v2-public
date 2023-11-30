// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./WadRayMath.sol";

library AaveAdapterLib {
    // Also denote this function as f(share) for a given (constant) index
    function calcSharesToAssetDown(uint256 amountShares, uint256 index) internal pure returns (uint256) {
        return (amountShares * index) / WadRayMath.RAY;
    }

    function calcSharesFromAssetDown(uint256 amountAssets, uint256 index) internal pure returns (uint256) {
        return (amountAssets * WadRayMath.RAY) / index;
    }

    function calcSharesFromAssetUp(uint256 amountAssets, uint256 index) internal pure returns (uint256) {
        return WadRayMath.rayDiv(amountAssets, index);
    }
}

// More functions denote:
// - up(division) = round up of division
// - down(division) = round down of division (same as normal /, just for better demonstration)
//
// Since aave only allows burning aToken on underlying amount (conversion is done inside aave contract)
//
// Thus, we'd need to ensure the amount of SY we burn from users is at least the amount of scaled balance
// burned in aave.
//
// Aave conversion equation: g(asset) = up(asset * RAY / index)
// Our conversion function:  f(share) = down(share * index / RAY)
//
// So we have p(share) = g(f(share)) = up(f(share) * RAY / index)
//
// Observation: Rounding down in f would not be enough to ensure share >= p(share) since they are results
// of different divisions
//
// It's obvious that: p(share) <= f(share) * RAY / index + 1
// where f(share) * RAY / index = down(share * index / RAY) * RAY / index <= share
//
// As a result p(share) <= share + 1 and share + 1 should be a correct upperbound for the amount of share being
// burnt in aave system
//
// CONCLUSION: When user burn SY, we calculate their underlying amount using (share - 1) scaled balance
