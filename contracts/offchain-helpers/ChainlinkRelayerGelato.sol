// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./AutomateReady.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../core/StandardizedYield/implementations/ChainlinkRelayer/PendleChainlinkRelayer.sol";

contract ChainlinkRelayerGelato is AutomateReady, BoringOwnableUpgradeable {
    PendleChainlinkRelayer public immutable relayer;

    int256 public lastSentAnswer;

    constructor(address _automate, address _taskCreator, PendleChainlinkRelayer _relayer) initializer
    AutomateReady(_automate, _taskCreator) {
        __BoringOwnable_init();
        relayer = _relayer;
    }

    receive() external payable {}

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function run() external {
        int256 latestAnswer = IChainlinkAggregator(relayer.chainlinkFeed()).latestAnswer();
        require(lastSentAnswer != latestAnswer, "answer not new");

        (uint256 fee, address feeToken) = _getFeeDetails();
        _transfer(fee, feeToken);

        relayer.run{value: address(this).balance}();
        lastSentAnswer = latestAnswer;
    }
}

