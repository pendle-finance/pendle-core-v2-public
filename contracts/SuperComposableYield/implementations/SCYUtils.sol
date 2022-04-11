// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../ISuperComposableYield.sol";
import "../../libraries/math/FixedPoint.sol";

library SCYUtils {
    using FixedPoint for uint256;
    using FixedPoint for int256;

    function scyToAsset(uint256 scyIndex, uint256 scyAmount) internal pure returns (uint256) {
        return scyAmount.mulDown(scyIndex);
    }

    function assetToScy(uint256 scyIndex, uint256 assetAmount) internal pure returns (uint256) {
        return assetAmount.divDown(scyIndex);
    }

    function scyToAsset(uint256 scyIndex, int256 scyAmount) internal pure returns (int256) {
        return scyAmount.mulDown(scyIndex);
    }

    function assetToScy(uint256 scyIndex, int256 assetAmount) internal pure returns (int256) {
        return assetAmount.divDown(scyIndex);
    }

    function scyToAsset(int256 scyIndex, int256 scyAmount) internal pure returns (int256) {
        return scyAmount.mulDown(scyIndex);
    }

    function assetToScy(int256 scyIndex, int256 assetAmount) internal pure returns (int256) {
        return assetAmount.divDown(scyIndex);
    }
}
