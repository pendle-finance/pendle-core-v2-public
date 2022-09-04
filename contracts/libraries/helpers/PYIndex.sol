// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;
import "../../interfaces/IPYieldToken.sol";
import "../../interfaces/IPPrincipalToken.sol";
import "../SCY/SCYUtils.sol";
import "../math/Math.sol";

type PYIndex is uint256;

library PYIndexLib {
    using Math for uint256;
    using Math for int256;

    function newIndex(IPYieldToken YT) internal returns (PYIndex) {
        return PYIndex.wrap(YT.pyIndexCurrent());
    }

    function scyToAsset(PYIndex index, uint256 scyAmount)
        internal
        pure
        returns (uint256)
    {
        return SCYUtils.scyToAsset(PYIndex.unwrap(index), scyAmount);
    }

    function assetToScy(PYIndex index, uint256 assetAmount)
        internal
        pure
        returns (uint256)
    {
        return SCYUtils.assetToScy(PYIndex.unwrap(index), assetAmount);
    }

    function assetToScyUp(PYIndex index, uint256 assetAmount)
        internal
        pure
        returns (uint256)
    {
        return SCYUtils.assetToScyUp(PYIndex.unwrap(index), assetAmount);
    }

    function scyToAssetUp(PYIndex index, uint256 scyAmount)
        internal
        pure
        returns (uint256)
    {
        uint256 _index = PYIndex.unwrap(index);
        return SCYUtils.scyToAssetUp(_index, scyAmount);
    }

    function scyToAsset(PYIndex index, int256 scyAmount)
        internal
        pure
        returns (int256)
    {
        int256 sign = scyAmount < 0 ? int256(-1) : int256(1);
        return sign * (SCYUtils.scyToAsset(PYIndex.unwrap(index), scyAmount.abs())).Int();
    }

    function assetToScy(PYIndex index, int256 assetAmount)
        internal
        pure
        returns (int256)
    {
        int256 sign = assetAmount < 0 ? int256(-1) : int256(1);
        return sign * (SCYUtils.assetToScy(PYIndex.unwrap(index), assetAmount.abs())).Int();
    }

    function assetToScyUp(PYIndex index, int256 assetAmount)
        internal
        pure
        returns (int256)
    {
        int256 sign = assetAmount < 0 ? int256(-1) : int256(1);
        return sign * (SCYUtils.assetToScyUp(PYIndex.unwrap(index), assetAmount.abs())).Int();
    }

}
