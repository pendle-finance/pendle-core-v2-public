// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../../interfaces/ISuperComposableYield.sol";
import "./SCYUtils.sol";
import "../math/Math.sol";

type SCYIndex is uint256;

library SCYIndexLib {
    using Math for uint256;
    using Math for int256;

    function newIndex(ISuperComposableYield SCY) internal view returns (SCYIndex) {
        return SCYIndex.wrap(SCY.exchangeRate());
    }

    function newIndex(address SCY) internal view returns (SCYIndex) {
        return SCYIndex.wrap(ISuperComposableYield(SCY).exchangeRate());
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
        int256 sign = scyAmount < 0 ? int256(-1) : int256(1);
        return sign * (SCYUtils.scyToAsset(SCYIndex.unwrap(index), scyAmount.abs())).Int();
    }

    function assetToScy(SCYIndex index, int256 assetAmount)
        internal
        pure
        returns (int256)
    {
        int256 sign = assetAmount < 0 ? int256(-1) : int256(1);
        return sign * (SCYUtils.assetToScy(SCYIndex.unwrap(index), assetAmount.abs())).Int();
    }

}
