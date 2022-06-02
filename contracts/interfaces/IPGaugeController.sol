// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPGaugeController {
    function pendle() external returns (address);

    function claimMarketReward() external;

    function rewardData(address pool)
        external
        view
        returns (
            uint128 pendlePerSec,
            uint128,
            uint128,
            uint128
        );
}
