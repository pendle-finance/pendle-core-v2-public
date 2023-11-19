// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPGaugeController.sol";

interface IPGaugeControllerMainchain is IPGaugeController {
    function updateVotingResults(uint128 wTime, address[] calldata markets, uint256[] calldata pendleSpeeds) external;
}
