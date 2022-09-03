// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleFeeDistributorAbstract.sol";
import "../../../interfaces/IPVotingController.sol";

contract PendleFeeDistributorVoting is PendleFeeDistributorAbstract {
    using Math for uint256;

    address public immutable votingController;
    address public immutable pool;

    constructor(address _votingController, address _pool) {
        votingController = _votingController;
        pool = _pool;
    }

    function _getUserCheckpointsLength(address user)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return IPVotingController(votingController).getUserPoolHistoryLength(user, pool);
    }

    function _getUserCheckpointAt(address user, uint256 index)
        internal
        view
        virtual
        override
        returns (Checkpoint memory)
    {
        return IPVotingController(votingController).getUserPoolHistoryAt(user, pool, index);
    }

    function _getTotalSharesAt(uint256 timestamp)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        assert(WeekMath.isValidWTime(timestamp.Uint128()));

        address[] memory pools = new address[](1);
        pools[0] = pool;

        (, , uint128[] memory votes) = IPVotingController(votingController).getWeekData(
            timestamp.Uint128(),
            pools
        );
        return votes[0];
    }

    function _updateGlobalShares() internal virtual override {
        IPVotingController(votingController).applyPoolSlopeChanges(pool);
    }
}
