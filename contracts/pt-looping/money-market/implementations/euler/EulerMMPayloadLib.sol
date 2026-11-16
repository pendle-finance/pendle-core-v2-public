//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IEulerFactory} from "./dependencies/IEulerFactory.sol";
import {IEulerVault} from "./dependencies/IEulerVault.sol";

/// @dev Payload: high 128 bits = base (PT) vault index, low 128 bits = quote (debt) vault index, in
/// the factory's `proxyList`.
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
