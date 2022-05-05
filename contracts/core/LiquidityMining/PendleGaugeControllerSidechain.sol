// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleGaugeController.sol";
import "./CelerAbstracts/CelerReceiver.sol";

contract PendleGaugeControllerSidechain is PendleGaugeController, CelerReceiver {
    address public immutable votingController;

    constructor(
        address _votingController,
        address _pendle,
        address _marketFactory,
        address _governanceManager
    ) PendleGaugeController(_pendle, _marketFactory) CelerReceiver(_governanceManager) {
        votingController = _votingController;
    }

    function _executeMessage(bytes memory message) internal virtual override {
        (uint256 pendleAcquired, address lpToken, uint256 newVote) = abi.decode(
            message,
            (uint256, address, uint256)
        );
        _updateLpVote(pendleAcquired, lpToken, newVote);
    }
}
