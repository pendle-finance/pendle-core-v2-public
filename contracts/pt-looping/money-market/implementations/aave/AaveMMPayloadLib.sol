//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/// @dev The low byte is `eModeCategoryId`. 0: no eMode.
library AaveMMPayloadLib {
    function unwrap(bytes32 payload) internal pure returns (uint8 eModeCategoryId) {
        uint256 rawPayload = uint256(payload);
        eModeCategoryId = uint8(rawPayload);
    }
}
