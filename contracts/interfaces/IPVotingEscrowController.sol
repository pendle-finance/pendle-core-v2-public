// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.14;

interface IPVotingEscrowController {
    function pendlePerSec() external returns (uint256);

    function totalVote() external returns (uint256);

    /**
     * @return vote Amount of vePendle voted for pool
     * @return pendleSpeed Amount of Pendle incentivized for pool per second
     */
    function readPoolRewardInfo(address pool) external returns (uint256 vote, uint256 pendleSpeed);
}
