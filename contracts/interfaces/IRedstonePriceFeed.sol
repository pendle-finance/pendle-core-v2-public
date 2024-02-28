pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IRedstonePriceFeed is AggregatorV3Interface {
    /**
     * @notice Old Chainlink function for getting the number of latest round
     * @return latestRound The number of the latest update round
     */
    function latestRound() external view returns (uint80);

    /**
     * @notice Old Chainlink function for getting the latest successfully reported value
     * @return latestAnswer The latest successfully reported value
     */
    function latestAnswer() external view returns (int256);
}
