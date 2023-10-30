// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../core/StandardizedYield/implementations/ChainlinkRelayer/PendleChainlinkRelayer.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract ChainlinkRelayerAutomation is AutomationCompatible, BoringOwnableUpgradeable {
    PendleChainlinkRelayer internal immutable relayer;
    bytes32 internal constant ZERO_BYTES = bytes32(0);

    int256 public answerLastSent;

    constructor(PendleChainlinkRelayer _relayer) initializer {
        __BoringOwnable_init();
        relayer = _relayer;
    }

    receive() external payable {}

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function checkUpkeep(
        bytes calldata /*checkData*/
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /*performData*/
        )
    {
        (upkeepNeeded, ) = _checkUpkeep();
    }

    function performUpkeep(
        bytes calldata /*performData*/
    ) public {
        (bool upkeepNeeded, int256 latestAnswer) = _checkUpkeep();
        require(upkeepNeeded, "no upkeep needed");

        relayer.run{ value: address(this).balance }();
        answerLastSent = latestAnswer;
    }

    function _checkUpkeep() internal view returns (bool upkeepNeeded, int256 latestAnswer) {
        latestAnswer = IChainlinkAggregator(relayer.chainlinkFeed()).latestAnswer();
        return (latestAnswer != answerLastSent, latestAnswer);
    }
}
