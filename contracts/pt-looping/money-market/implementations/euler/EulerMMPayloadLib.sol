//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IEulerFactory} from "./dependencies/IEulerFactory.sol";
import {IEulerVault} from "./dependencies/IEulerVault.sol";

/// Library for decoding Euler MM payloads.
/// - The first 128 bits are the base (PT) vault index.
/// - The last 128 bits are the quote (debt) vault index.
library EulerMMPayloadLib {
    function unwrap(bytes32 payload) internal pure returns (uint128 baseIndex, uint128 quoteIndex) {
        baseIndex = uint128(uint256(payload) >> 128);
        quoteIndex = uint128(uint256(payload));
    }

    function baseVault(IEulerFactory factory, bytes32 payload) internal view returns (IEulerVault) {
        (uint128 baseIndex,) = unwrap(payload);
        return IEulerVault(factory.proxyList(baseIndex));
    }

    function quoteVault(IEulerFactory factory, bytes32 payload) internal view returns (IEulerVault) {
        (, uint128 quoteIndex) = unwrap(payload);
        return IEulerVault(factory.proxyList(quoteIndex));
    }
}
