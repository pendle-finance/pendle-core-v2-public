// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleGaugeControllerBaseUpg.sol";

/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it inherits only upgradable contract
contract PendleGaugeControllerMainchainUpg is PendleGaugeControllerBaseUpg {
    address public immutable votingController;

    modifier onlyVotingController() {
        require(msg.sender == votingController, "not voting controller");
        _;
    }

    constructor(
        address _votingController,
        address _pendle,
        address _marketFactory
    ) PendleGaugeControllerBaseUpg(_pendle, _marketFactory) {
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
