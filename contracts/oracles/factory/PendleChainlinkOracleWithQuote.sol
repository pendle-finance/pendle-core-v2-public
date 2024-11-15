// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracleBase.sol";

/**
 * @dev The round data returned from this contract will follow:
 * - There will be only one round (roundId=0)
 * - startedAt=0, updatedAt=quoteOracle.updatedAt()
 */
contract PendleChainlinkOracleWithQuote is PendleChainlinkOracleBase {
    // solhint-disable immutable-vars-naming
    address public immutable quoteOracle;
    int256 public immutable quoteScale;

    constructor(
        address _market,
        uint16 _twapDuration,
        PendleOracleType _baseOracleType,
        address _quoteOracle
    ) PendleChainlinkOracleBase(_market, _twapDuration, _baseOracleType) {
        quoteOracle = _quoteOracle;
        quoteScale = PMath.Int(10 ** AggregatorV3Interface(quoteOracle).decimals());
    }

    function _getFinalPrice() internal view virtual override returns (int256) {
        (, int256 quoteAnswer, , , ) = AggregatorV3Interface(quoteOracle).latestRoundData();
        return (_getPendleTokenPrice() * quoteAnswer) / quoteScale;
    }

    function latestRoundData()
        public
        view
        virtual
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (, int256 quoteAnswer, , uint256 quoteUpdatedAt, ) = AggregatorV3Interface(quoteOracle).latestRoundData();

        roundId = 0;
        answer = (_getPendleTokenPrice() * quoteAnswer) / quoteScale;
        startedAt = 0;
        updatedAt = quoteUpdatedAt;
        answeredInRound = 0;
    }
}
