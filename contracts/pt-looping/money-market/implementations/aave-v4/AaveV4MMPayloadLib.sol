//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {ISpoke} from "./dependencies/ISpoke.sol";

/// @dev Payload, from the high bits: the Spoke address (160), the collateral reserve id (48), the debt reserve
/// id (48).
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
