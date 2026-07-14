//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/// @dev Encoding:
/// - first byte: to encode eModeCategoryId
/// - second byte, bit 0: isolationMode flag
/// @dev eModeCategoryId == 0 means no eMode
library AaveMMPayloadLib {
    uint256 private constant ISOLATION_MODE_MASK = 1 << 8;

    function unwrap(bytes32 payload) internal pure returns (uint8 eModeCategoryId, bool isolationMode) {
        uint256 rawPayload = uint256(payload);
        eModeCategoryId = uint8(rawPayload);
        isolationMode = (rawPayload & ISOLATION_MODE_MASK) != 0;
    }
}
