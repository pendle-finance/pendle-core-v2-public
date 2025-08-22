// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

/**
 * @title PendleLpLinearDiscountOracle
 * @notice Oracle for pricing Pendle LP tokens using a linear discount model based on time to maturity
 * @dev Implements Chainlink-compatible price feed interface for LP tokens
 * The oracle calculates LP price by applying a time-based linear discount to the PT component
 */
contract PendleLpLinearDiscountOracle {
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant ONE = 1e18;

    /// @notice The LP token address (Pendle Market)
    address public immutable LP;

    /// @notice The maturity timestamp of the LP token
    uint256 public immutable maturity;

    /// @notice Annual discount rate for LP tokens (1e18 = 100%)
    uint256 public immutable baseLpDiscountPerYear;

    /// @notice Base price multiplier for LP tokens (1e18 = 1x)
    uint256 public immutable lpMaturedPrice;

    constructor(address _lp, uint256 _baseLpDiscountPerYear, uint256 _lpMaturedPrice) {
        require(_lpMaturedPrice >= 1e18, "invalid price");

        LP = _lp;
        maturity = LPExpiry(LP).expiry();
        baseLpDiscountPerYear = _baseLpDiscountPerYear;
        lpMaturedPrice = _lpMaturedPrice;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        uint256 timeLeft = (maturity > block.timestamp) ? maturity - block.timestamp : 0;
        uint256 lpPrice = getLpPrice(timeLeft);
        return (0, int256(lpPrice), 0, 0, 0);
    }

    function getLpPrice(uint256 timeLeft) public view returns (uint256) {
        uint256 lpDiscount = getLpDiscount(timeLeft);
        require(lpDiscount <= ONE, "discount overflow");

        uint256 lpPrice = ((ONE - lpDiscount) * lpMaturedPrice) / ONE;

        return lpPrice;
    }

    function getLpDiscount(uint256 timeLeft) public view returns (uint256) {
        return (timeLeft * baseLpDiscountPerYear) / SECONDS_PER_YEAR;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}

interface LPExpiry {
    function expiry() external view returns (uint256);
}
