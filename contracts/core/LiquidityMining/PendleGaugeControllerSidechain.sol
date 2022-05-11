// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleGaugeController.sol";
import "./CelerAbstracts/CelerReceiver.sol";

contract PendleGaugeControllerSidechain is PendleGaugeController, CelerReceiver {

    constructor(
        address _pendle,
        address _marketFactory,
        address _governanceManager
    ) PendleGaugeController(_pendle, _marketFactory) CelerReceiver(_governanceManager) {}

    function _executeMessage(bytes memory message) internal virtual override {
        (uint256 epochStart, address[] memory markets, uint256[] memory pendleSpeeds) = abi.decode(
            message,
            (uint256, address[], uint256[])
        );
        _receiveVotingResults(epochStart, markets, pendleSpeeds);
    }
}
