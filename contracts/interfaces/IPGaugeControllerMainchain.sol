// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./IPGaugeController.sol";

interface IPGaugeControllerMainchain is IPGaugeController {
    function updateVotingResults(
        uint256 epochStart,
        address[] calldata markets,
        uint256[] calldata pendleSpeeds
    ) external;
}
