// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

struct VeBalance {
    uint256 bias;
    uint256 slope;
}

struct Checkpoint {
    VeBalance balance;
    uint256 timestamp;
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
        uint256 slope,
        uint256 expiry
    ) internal pure returns (VeBalance memory res) {
        res.slope = a.slope - slope;
        res.bias = a.bias - slope * expiry;
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

    function getExpiry(VeBalance memory a) internal pure returns (uint256) {
        require(a.slope > 0, "invalid VeBalance");
        return a.bias / a.slope; // this is guaranteed to be true
    }

    // hmm I'm not the biggest fan of the random hooks, very hard to rmb when to call
    // and this is not "isValid"
    function isValid(VeBalance memory a) internal view returns (bool) {
        return a.slope > 0 && getExpiry(a) > block.timestamp;
    }
}
