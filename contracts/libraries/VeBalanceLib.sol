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

    function getCurrentValue(VeBalance memory a) internal view returns (uint128) {
        if (isExpired(a)) return 0;
        return getValueAt(a, uint128(block.timestamp));
    }

    function getValueAt(VeBalance memory a, uint128 t) internal pure returns (uint128) {
        return a.bias - a.slope * t;
    }

    function getExpiry(VeBalance memory a) internal pure returns (uint128) {
        require(a.slope != 0, "zero slope");
        return a.bias / a.slope;
    }

    function getCheckpointValueAt(Checkpoint[] storage checkpoints, uint128 timestamp)
        internal
        view
        returns (uint128)
    {
        if (checkpoints.length == 0 || checkpoints[0].timestamp > timestamp) {
            return 0;
        }

        uint256 left = 0;
        uint256 right = checkpoints.length;

        while (left < right) {
            uint256 mid = (left + right) / 2;
            if (checkpoints[mid].timestamp <= timestamp) {
                left = mid;
            } else {
                right = mid - 1;
            }
        }

        VeBalance memory bal = checkpoints[left].balance;
        if (getExpiry(bal) <= timestamp) {
            return 0;
        } else {
            return getValueAt(bal, timestamp);
        }
    }
}
