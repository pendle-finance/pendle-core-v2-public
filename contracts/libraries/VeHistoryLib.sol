// SPDX-License-Identifier: MIT
// Forked from OpenZeppelin (v4.5.0) (utils/Checkpoints.sol)
pragma solidity ^0.8.0;

import "./math/Math.sol";
import "./VeBalanceLib.sol";
import "./math/WeekMath.sol";

struct Checkpoint {
    uint128 timestamp;
    VeBalance value;
}

library Checkpoints {
    struct History {
        Checkpoint[] _checkpoints;
    }

    function length(History storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    function get(History storage self, uint256 index) internal view returns (Checkpoint memory) {
        return self._checkpoints[index];
    }

    /**
     * @dev Pushes a value onto a History so that it is stored as the checkpoint for the current block.
     *
     * Returns previous value and new value.
     */
    function push(History storage self, VeBalance memory value) internal {
        uint256 pos = self._checkpoints.length;
        if (
            pos > 0 &&
            WeekMath.isInTheSameEpoch(self._checkpoints[pos - 1].timestamp, block.timestamp)
        ) {
            self._checkpoints[pos - 1].value = value;
        } else {
            self._checkpoints.push(
                Checkpoint({ timestamp: uint128(block.timestamp), value: value })
            );
        }
    }
}
