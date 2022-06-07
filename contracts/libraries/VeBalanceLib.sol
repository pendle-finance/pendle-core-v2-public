// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

struct VeBalance {
    uint128 bias;
    uint128 slope;
}

struct Checkpoint {
    VeBalance balance;
    uint128 timestamp;
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

    function sub(
        VeBalance memory a,
        uint128 slope,
        uint128 expiry
    ) internal pure returns (VeBalance memory res) {
        res.slope = a.slope - slope;
        res.bias = a.bias - slope * expiry;
    }

    function isExpired(VeBalance memory a) internal view returns (bool) {
        return a.slope * uint128(block.timestamp) >= a.bias;
    }

    function getValueAt(VeBalance memory a, uint128 t) internal pure returns (uint128) {
        return a.bias - a.slope * t;
    }

    function getCurrentValue(VeBalance memory a) internal view returns (uint128) {
        if (isExpired(a)) return 0;
        return getValueAt(a, uint128(block.timestamp));
    }

    function getExpiry(VeBalance memory a) internal pure returns (uint128) {
        require(a.slope > 0, "invalid VeBalance");
        return a.bias / a.slope; // this is guaranteed to be true
    }

    // hmm I'm not the biggest fan of the random hooks, very hard to rmb when to call
    // and this is not "isValid"
}
