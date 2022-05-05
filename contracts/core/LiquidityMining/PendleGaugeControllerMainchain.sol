// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleGaugeController.sol";

contract PendleGaugeControllerMainchain is PendleGaugeController {
    address public immutable votingController;

    constructor(
        address _votingController,
        address _pendle,
        address _marketFactory
    ) PendleGaugeController(_pendle, _marketFactory) {
        votingController = _votingController;
    }

    function updateLpVote(
        uint256 pendleAcquired,
        address lpToken,
        uint256 newVote
    ) external {
        require(msg.sender == votingController, "not voting controller");
        _updateLpVote(pendleAcquired, lpToken, newVote);
    }
}
