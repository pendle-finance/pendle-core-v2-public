// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../ILiquidYieldToken.sol";
import "../../libraries/math/FixedPoint.sol";

library LYTUtils {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    function assetToLyt(ILiquidYieldToken lyt, uint256 assetAmount) internal returns (uint256) {
        return assetToLyt(lyt.lytIndexCurrent(), assetAmount);
    }

    function lytToAsset(ILiquidYieldToken lyt, uint256 lytAmount) internal returns (uint256) {
        return lytToAsset(lyt.lytIndexCurrent(), lytAmount);
    }

    function lytToAsset(uint256 lytIndex, uint256 lytAmount) internal pure returns (uint256) {
        return lytAmount.mulDown(lytIndex);
    }

    function assetToLyt(uint256 lytIndex, uint256 assetAmount) internal pure returns (uint256) {
        return assetAmount.divDown(lytIndex);
    }

    function assetToLyt(ILiquidYieldToken lyt, int256 assetAmount) internal returns (int256) {
        return assetToLyt(lyt.lytIndexCurrent(), assetAmount);
    }

    function lytToAsset(ILiquidYieldToken lyt, int256 lytAmount) internal returns (int256) {
        return lytToAsset(lyt.lytIndexCurrent(), lytAmount);
    }

    function lytToAsset(uint256 lytIndex, int256 lytAmount) internal pure returns (int256) {
        return lytAmount.mulDown(lytIndex);
    }

    function assetToLyt(uint256 lytIndex, int256 assetAmount) internal pure returns (int256) {
        return assetAmount.divDown(lytIndex);
    }

    function lytToAsset(int256 lytIndex, int256 lytAmount) internal pure returns (int256) {
        return lytAmount.mulDown(lytIndex);
    }

    function assetToLyt(int256 lytIndex, int256 assetAmount) internal pure returns (int256) {
        return assetAmount.divDown(lytIndex);
    }
}
