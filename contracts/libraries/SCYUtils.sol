// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

library SCYUtils {
    uint256 internal constant ONE = 1e18;

    function scyToAsset(uint256 exchangeRate, uint256 scyAmount) internal pure returns (uint256) {
        return (scyAmount * exchangeRate) / ONE;
    }

    function assetToScy(uint256 exchangeRate, uint256 assetAmount)
        internal
        pure
        returns (uint256)
    {
        return (assetAmount * ONE) / exchangeRate;
    }
}
