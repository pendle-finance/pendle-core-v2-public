// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleGaugeControllerBaseUpg.sol";
import "../CelerAbstracts/CelerReceiverUpg.sol";

// solhint-disable no-empty-blocks

/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it inherits only upgradable contract
contract PendleGaugeControllerSidechainUpg is PendleGaugeControllerBaseUpg, CelerReceiverUpg {
    constructor(
        address _pendle,
        address _marketFactory
    ) PendleGaugeControllerBaseUpg(_pendle, _marketFactory) {}

    function _executeMessage(bytes memory message) internal virtual override {
        (uint128 wTime, address[] memory markets, uint256[] memory pendleAmounts) = abi.decode(
            message,
            (uint128, address[], uint256[])
        );
        _receiveVotingResults(wTime, markets, pendleAmounts);
    }
}
