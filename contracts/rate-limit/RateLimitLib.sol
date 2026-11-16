// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {PMath} from "../core/libraries/math/PMath.sol";

/// @dev netBurn > 0 is burn volume consuming the capacity, < 0 is credit banked by mints.
/// It decays toward zero at capacity per decay window and never leaves [-capacity, capacity].
struct RateLimitData {
    // slot 0: written on every hook
    int224 netBurn;
    uint32 lastUpdated;
    // slot 1: governance only
    uint192 capacity;
    uint32 burnDecayWindow;
    uint32 mintDecayWindow;
}

using RateLimitLib for RateLimitData global;

library RateLimitLib {
    /// @dev amounts are in shares for a token meter, in 18-decimal USD when `isAggregate`
    error BurnLimitExceeded(address token, address account, uint256 requested, uint256 available, bool isAggregate);

    function recordMint(RateLimitData storage self, uint256 amount) internal {
        if (amount == 0) return;

        (int256 net, int256 cap,) = _settled(self);
        _store(self, PMath.max(net - PMath.Int(amount), -cap));
    }

    /// @dev `token` is the SY being burned, also for the aggregate meter
    function recordBurn(RateLimitData storage self, uint256 amount, address token, address account, bool isAggregate)
        internal
    {
        if (amount == 0) return;

        (int256 net,, uint256 available) = _settled(self);
        require(amount <= available, BurnLimitExceeded(token, account, amount, available, isAggregate));
        _store(self, net + PMath.Int(amount));
    }

    function resetNetBurn(RateLimitData storage self) internal {
        _store(self, 0);
    }

    function setCapacity(RateLimitData storage self, uint192 capacity) internal {
        (int256 net,,) = _settled(self);
        self.capacity = capacity;
        _store(self, PMath.clamp(net, -PMath.Int(capacity), PMath.Int(capacity)));
    }

    function setDecayWindow(RateLimitData storage self, uint32 burnDecayWindow, uint32 mintDecayWindow) internal {
        // book the decay accrued under the old windows before switching
        (int256 net,,) = _settled(self);
        self.burnDecayWindow = burnDecayWindow;
        self.mintDecayWindow = mintDecayWindow;
        _store(self, net);
    }

    function availableBurn(RateLimitData storage self) internal view returns (uint256 available) {
        (,, available) = _settled(self);
    }

    /// @dev |net| <= capacity <= uint192.max, so the int224 cast cannot truncate
    function _store(RateLimitData storage self, int256 net) private {
        self.netBurn = int224(net);
        self.lastUpdated = uint32(block.timestamp);
    }

    function _settled(RateLimitData storage self) private view returns (int256 net, int256 cap, uint256 available) {
        net = self.netBurn;
        cap = PMath.Int(self.capacity);

        uint256 window = net > 0 ? self.burnDecayWindow : self.mintDecayWindow;
        uint256 elapsed = block.timestamp - self.lastUpdated;
        if (window != 0 && elapsed != 0) {
            uint256 decay = uint256(self.capacity) * elapsed / window;
            uint256 magnitude = PMath.abs(net);
            int256 remaining = magnitude > decay ? PMath.Int(magnitude - decay) : int256(0);
            net = net > 0 ? remaining : -remaining;
        }
        available = PMath.Uint(cap - net);
    }
}
