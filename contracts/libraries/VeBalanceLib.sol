// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

struct VeBalance {
    uint256 bias;
    uint256 slope;
}

library VeBalanceLib {
    function add(VeBalance memory a, VeBalance memory b)
        internal
        pure
        returns (VeBalance memory res)
    {
        res.bias = a.bias + b.bias;
        res.slope = a.slope + b.slope;
    }

    function sub(VeBalance memory a, VeBalance memory b)
        internal
        pure
        returns (VeBalance memory res)
    {
        res.bias = a.bias - b.bias;
        res.slope = a.slope - b.slope;
    }

    function isExpired(VeBalance memory a) internal view returns (bool) {
        return a.slope * block.timestamp >= a.bias;
    }

    function getValueAt(VeBalance memory a, uint256 t) internal pure returns (uint256) {
        return a.bias - a.slope * t;
    }

    function getCurrentValue(VeBalance memory a) internal view returns (uint256) {
        if (isExpired(a)) return 0;
        return getValueAt(a, block.timestamp);
    }
}
