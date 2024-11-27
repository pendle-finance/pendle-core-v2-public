// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

contract PendleSparkLinearDiscountOracle {
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant ONE = 1e18;

    address public immutable PT;
    uint256 public immutable maturity;
    uint256 public immutable baseDiscountPerYear; // 100% = 1e18

    constructor(address _pt, uint256 _baseDiscountPerYear) {
        require(_baseDiscountPerYear <= 1e18, "invalid discount");
        require(_pt != address(0), "zero address");

        PT = _pt;
        maturity = PTExpiry(PT).expiry();
        baseDiscountPerYear = _baseDiscountPerYear;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        uint256 timeLeft = (maturity > block.timestamp) ? maturity - block.timestamp : 0;
        uint256 discount = getDiscount(timeLeft);

        require(discount <= ONE, "discount overflow");

        return (0, int256(ONE - discount), 0, 0, 0);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function getDiscount(uint256 timeLeft) public view returns (uint256) {
        return (timeLeft * baseDiscountPerYear) / SECONDS_PER_YEAR;
    }
}

interface PTExpiry {
    function expiry() external view returns (uint256);
}
