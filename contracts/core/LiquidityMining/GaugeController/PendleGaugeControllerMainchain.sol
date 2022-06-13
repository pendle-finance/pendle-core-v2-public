// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./PendleGaugeController.sol";

contract PendleGaugeControllerMainchain is PendleGaugeController {
    address public immutable votingController;

    modifier onlyVotingController() {
        require(msg.sender == votingController, "not voting controller");
        _;
    }

    constructor(
        address _votingController,
        address _pendle,
        address _marketFactory,
        address _governanceManager
    ) PendleGaugeController(_pendle, _marketFactory) PermissionsV2Upg(_governanceManager) {
        votingController = _votingController;
    }

    function updateVotingResults(
        uint128 wTime,
        address[] memory markets,
        uint256[] memory pendleSpeeds
    ) external onlyVotingController {
        _receiveVotingResults(wTime, markets, pendleSpeeds);
    }
}
