// SPDX-License-Identifier: MIT
// Forked from OpenZeppelin (v4.5.0) (utils/Checkpoints.sol)
pragma solidity ^0.8.0;

import "./math/Math.sol";
import "./VeBalanceLib.sol";

library Checkpoints {
    struct Checkpoint {
        uint32 _timestamp;
        VeBalance _value;
    }

    struct History {
        Checkpoint[] _checkpoints;
    }

    /**
     * @dev Returns the value at a given block number. If a checkpoint is not available at that block, the closest one
     * before it is returned, or zero otherwise.
     */
    function getAtTimestamp(History storage self, uint256 timestamp)
        internal
        view
        returns (uint128)
    {
        require(timestamp < block.timestamp, "Checkpoints: block not yet mined");

        uint256 high = self._checkpoints.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (self._checkpoints[mid]._timestamp > timestamp) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return
            high == 0
                ? 0
                : VeBalanceLib.getValueAt(self._checkpoints[high - 1]._value, uint128(timestamp));
    }

    /**
     * @dev Pushes a value onto a History so that it is stored as the checkpoint for the current block.
     *
     * Returns previous value and new value.
     */
    function push(History storage self, VeBalance memory value) internal {
        uint256 pos = self._checkpoints.length;
        if (pos > 0 && self._checkpoints[pos - 1]._timestamp == block.timestamp) {
            self._checkpoints[pos - 1]._value = value;
        } else {
            self._checkpoints.push(
                Checkpoint({ _timestamp: uint32(block.timestamp), _value: value })
            );
        }
    }
}
