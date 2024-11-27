// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./PendleChainlinkOracle.sol";

/**
 * @dev The round data returned from this contract will follow:
 * - There will be only one round (roundId=0)
 * - startedAt=0, updatedAt=quoteOracle.updatedAt()
 */
contract PendleChainlinkOracleWithQuote is PendleChainlinkOracle {
    // solhint-disable immutable-vars-naming
    address public immutable quoteOracle;
    int256 public immutable quoteScale;

    constructor(
        address _market,
        uint32 _twapDuration,
        PendleOracleType _baseOracleType,
        address _quoteOracle
    ) PendleChainlinkOracle(_market, _twapDuration, _baseOracleType) {
        quoteOracle = _quoteOracle;
        quoteScale = PMath.Int(10 ** AggregatorV3Interface(_quoteOracle).decimals());
    }

    /**
     * @notice The round data returned from this contract will follow:
     * - answer will satisfy 1 natural unit of PendleToken = (answer/1e18) natural unit of quoteToken
     * - In other words, 10**(PendleToken.decimals) = (answer/1e18) * 10**(quoteToken.decimals)
     * @return roundId always 0 for this contract
     * @return answer The answer (in 18 decimals)
     * @return startedAt always 0 for this contract
     * @return updatedAt will be the same as quoteOracle.updatedAt()
     * @return answeredInRound always 0 for this contract
     */
    function latestRoundData()
        public
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (, int256 quoteAnswer, , uint256 quoteUpdatedAt, ) = AggregatorV3Interface(quoteOracle).latestRoundData();

        roundId = 0;
        answer = (_getPendleTokenPrice() * quoteAnswer) / quoteScale;
        updatedAt = quoteUpdatedAt;
        startedAt = 0;
        answeredInRound = 0;
    }
}
