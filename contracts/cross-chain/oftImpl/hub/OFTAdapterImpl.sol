// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";

// @notice Base OFT contract, without any additional functionality (like RateLimiter).
// @dev This contract inherits Ownable from OpenZeppelin v4.
// @dev Sender is set as the contract owner at deployment.
contract OFTAdapterImpl is OFTAdapter {
    constructor(address _token, address _endpoint, address _delegate) OFTAdapter(_token, _endpoint, _delegate) {}
}
