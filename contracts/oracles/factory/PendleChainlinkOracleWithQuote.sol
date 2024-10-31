// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracleBase.sol";

contract PendleChainlinkOracleWithQuote is PendleChainlinkOracleBase {
    // solhint-disable immutable-vars-naming
    address public immutable quoteOracle;
    int256 public immutable quoteScale;

    constructor(
        address _market,
        uint16 _twapDuration,
        PendleOraclePricingType _pricingType,
        PendleOracleTokenType _pricingToken,
        address _quoteOracle
    ) PendleChainlinkOracleBase(_market, _twapDuration, _pricingType, _pricingToken) {
        quoteOracle = _quoteOracle;
        quoteScale = int256(10 ** AggregatorV2V3Interface(_quoteOracle).decimals());
    }

    function _getFinalPrice() internal view virtual override returns (int256) {
        (, int256 quoteAnswer, , , ) = AggregatorV2V3Interface(quoteOracle).latestRoundData();
        return (_getPendleTokenPrice() * quoteAnswer) / quoteScale;
    }
}
