// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleFeeDistributorVoting.sol";
import "../../../interfaces/IPVotingController.sol";
import "../../../periphery/BoringOwnableUpgradeable.sol";

contract PendleFeeDistributorVotingFactory is BoringOwnableUpgradeable {
    address public immutable votingController;

    mapping(address => address) public distributorOf;

    constructor(address _votingController) {
        votingController = _votingController;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function createFeeDistributor(address pool) external onlyOwner {
        require(distributorOf[pool] == address(0), "distributor already created for pool");
        distributorOf[pool] = address(new PendleFeeDistributorVoting(votingController, pool));
    }
}
