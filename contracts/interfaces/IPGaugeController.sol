// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPGaugeController {
    function pendle() external returns (address);

    function redeemLpStakerReward() external;

    function rewardData(address pool)
        external
        view
        returns (
            uint256 pendlePerSec,
            uint256,
            uint256,
            uint256
        );
}
