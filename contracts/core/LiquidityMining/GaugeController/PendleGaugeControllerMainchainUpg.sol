// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./PendleGaugeControllerBaseUpg.sol";
import "../../../interfaces/IPGaugeControllerMainchain.sol";

/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it inherits only upgradable contract
contract PendleGaugeControllerMainchainUpg is
    PendleGaugeControllerBaseUpg,
    IPGaugeControllerMainchain
{
    address public immutable votingController;

    modifier onlyVotingController() {
        if (msg.sender != votingController) revert Errors.GCNotVotingController(msg.sender);
        _;
    }

    constructor(
        address _votingController,
        address _pendle,
        address _marketFactory
    ) PendleGaugeControllerBaseUpg(_pendle, _marketFactory) initializer {
        votingController = _votingController;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function updateVotingResults(
        uint128 wTime,
        address[] memory markets,
        uint256[] memory pendleSpeeds
    ) external onlyVotingController {
        _receiveVotingResults(wTime, markets, pendleSpeeds);
    }
}
