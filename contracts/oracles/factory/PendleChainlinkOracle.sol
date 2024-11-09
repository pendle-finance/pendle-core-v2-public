// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracleBase.sol";

/**
 * @dev The round data returned from this contract will follow:
 * - There will be only one round (roundId=0)
 * - startedAt, updatedAt will always be 0
 */
contract PendleChainlinkOracle is PendleChainlinkOracleBase {
    constructor(
        address _market,
        uint16 _twapDuration,
        PendleOracleType _baseOracleType
    ) PendleChainlinkOracleBase(_market, _twapDuration, _baseOracleType) {}

    function _getFinalPrice() internal view override returns (int256) {
        return _getPendleTokenPrice();
    }
}
