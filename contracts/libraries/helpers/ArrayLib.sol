// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../math/FixedPoint.sol";

library ArrayLib {
    using FixedPoint for uint256;

    function setValue(uint256[] storage arr, uint256 value) internal {
        for (uint256 i = 0; i < arr.length; i++) {
            arr[i] = value;
        }
    }

    function addEq(uint256[] storage arr, uint256[] memory arr2) internal {
        uint256 length = arr.length;
        require(length == arr2.length, "invalid length");
        for (uint256 i = 0; i < length; i++) {
            arr[i] += arr2[i];
        }
    }

    function eq(uint256[] storage arr, uint256[] storage arr2) internal view returns (bool) {
        if (arr.length != arr2.length) return false;
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] != arr2[i]) return false;
        }
        return true;
    }

    function add(uint256[] memory arr, uint256[] memory arr2)
        internal
        pure
        returns (uint256[] memory res)
    {
        require(arr.length == arr2.length, "invalid length");
        res = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            res[i] = arr[i] + arr2[i];
        }
    }

    function sub(uint256[] memory arr, uint256[] memory arr2)
        internal
        pure
        returns (uint256[] memory res)
    {
        require(arr.length == arr2.length, "invalid length");
        res = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            res[i] = arr[i] - arr2[i];
        }
    }

    function mulDown(uint256[] memory arr, uint256 x)
        internal
        pure
        returns (uint256[] memory res)
    {
        res = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            res[i] = arr[i].mulDown(x);
        }
    }

    function divDown(uint256[] memory arr, uint256 x)
        internal
        pure
        returns (uint256[] memory res)
    {
        res = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            res[i] = arr[i].divDown(x);
        }
    }

    function mul(uint256[] memory arr, uint256 x) internal pure returns (uint256[] memory res) {
        res = new uint256[](arr.length);
        for (uint256 i = 0; i < arr.length; i++) {
            res[i] = arr[i] * x;
        }
    }
}
