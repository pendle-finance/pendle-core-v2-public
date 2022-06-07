// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.13;

library WeekMath {
    uint128 internal constant WEEK = 7 days;

    function getWeekStartTimestamp(uint128 timestamp) internal pure returns (uint128) {
        return (timestamp / WEEK) * WEEK;
    }

    function getCurrentWeekStart() internal view returns (uint128) {
        return getWeekStartTimestamp(uint128(block.timestamp));
    }

    function isValidDuration(uint128 duration) internal pure returns (bool) {
        return duration % WEEK == 0;
    }
}
