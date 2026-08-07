//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISpoke} from "./dependencies/ISpoke.sol";

/// Library for decoding Aave V4 MM payloads.
/// - The top 160 bits are the Spoke address.
/// - The next 48 bits are the collateral reserveId.
/// - The bottom 48 bits are the debt reserveId.
library AaveV4MMPayloadLib {
    function unwrap(bytes32 payload)
        internal
        pure
        returns (ISpoke spoke, uint48 collateralReserveId, uint48 debtReserveId)
    {
        spoke = ISpoke(address(uint160(uint256(payload) >> (48 + 48))));
        collateralReserveId = uint48(uint256(payload) >> 48);
        debtReserveId = uint48(uint256(payload));
    }
}
