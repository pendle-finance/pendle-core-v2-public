// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

/// @dev This contract inherits Ownable from OpenZeppelin v4.
contract PendleOFT is OFT {
    constructor(address _lzEndpoint, address _delegate) OFT("Pendle", "PENDLE", _lzEndpoint, _delegate) {
        _transferOwnership(_delegate);
    }
}
