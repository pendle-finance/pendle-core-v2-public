// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleGaugeController.sol";

contract PendleGaugeControllerMainchain is PendleGaugeController {
    address public immutable votingController;

    constructor(
        address _votingController,
        address _pendle,
        address _marketFactory,
        address _governanceManager
    ) PendleGaugeController(_pendle, _marketFactory) PermissionsV2Upg(_governanceManager) {
        votingController = _votingController;
    }

    function updateVotingResults(
        uint256 epochStart,
        address[] memory markets,
        uint256[] memory pendleSpeeds
    ) external {
        require(msg.sender == votingController, "not voting controller");
        _receiveVotingResults(epochStart, markets, pendleSpeeds);
    }
}
