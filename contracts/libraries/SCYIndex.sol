// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../SuperComposableYield/ISuperComposableYield.sol";
import "../SuperComposableYield/SCYUtils.sol";
import "./math/FixedPoint.sol";

type SCYIndex is uint256;

library SCYIndexLib {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    function newIndex(ISuperComposableYield SCY) internal returns (SCYIndex) {
        return SCYIndex.wrap(SCY.scyIndexCurrent());
    }

    function newIndex(address SCY) internal returns (SCYIndex) {
        return SCYIndex.wrap(ISuperComposableYield(SCY).scyIndexCurrent());
    }

    function scyToAsset(SCYIndex index, uint256 scyAmount)
        internal
        pure
        returns (uint256)
    {
        return SCYUtils.scyToAsset(SCYIndex.unwrap(index), scyAmount);
    }

    function assetToScy(SCYIndex index, uint256 assetAmount)
        internal
        pure
        returns (uint256)
    {
        return SCYUtils.assetToScy(SCYIndex.unwrap(index), assetAmount);
    }

    function scyToAsset(SCYIndex index, int256 scyAmount)
        internal
        pure
        returns (int256)
    {
        return (SCYUtils.scyToAsset(SCYIndex.unwrap(index), scyAmount.Uint())).Int();
    }

    function assetToScy(SCYIndex index, int256 assetAmount)
        internal
        pure
        returns (int256)
    {
        return (SCYUtils.assetToScy(SCYIndex.unwrap(index), assetAmount.Uint())).Int();
    }

}
