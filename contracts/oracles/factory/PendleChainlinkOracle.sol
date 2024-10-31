// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracleBase.sol";

/**
 * @dev The round data returned from this contract will follow:
 * - There will be only one round (roundId=0)
 * - Timestamp of round 0 will always be block.timestamp
 * - Blocknumber of round 0 will always be block.number
 */
contract PendleChainlinkOracle is PendleChainlinkOracleBase {
    constructor(
        address _market,
        uint16 _twapDuration,
        PendleOraclePricingType _pricingType,
        PendleOracleTokenType _pricingToken
    ) PendleChainlinkOracleBase(_market, _twapDuration, _pricingType, _pricingToken) {}

    function _getFinalPrice() internal view virtual override returns (int256) {
        return _getPendleTokenPrice();
    }
}
