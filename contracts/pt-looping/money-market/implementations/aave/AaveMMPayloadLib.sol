//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/// @dev Encoding:
/// - first byte: to encode eModeCategoryId
/// @dev eModeCategoryId == 0 means no eMode
library AaveMMPayloadLib {
    function unwrap(bytes32 payload) internal pure returns (uint8 eModeCategoryId) {
        uint256 rawPayload = uint256(payload);
        eModeCategoryId = uint8(rawPayload);
    }
}
