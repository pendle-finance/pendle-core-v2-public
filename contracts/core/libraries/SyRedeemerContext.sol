// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

library SyRedeemerContext {
    // cast index-erc7201 "pendle.transient.SyRedeemerContext"
    bytes32 private constant SLOT = 0xe8cb61b87f041ce7ba1d7b88bf113ca84d0bcb904414c3716402eebd313d5c00;

    function get() internal view returns (address sender) {
        assembly ("memory-safe") {
            sender := tload(SLOT)
        }
    }

    function set() internal {
        assembly ("memory-safe") {
            tstore(SLOT, caller())
        }
    }

    function clear() internal {
        assembly ("memory-safe") {
            tstore(SLOT, 0)
        }
    }
}
