// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleFeeDistributorAbstract.sol";
import "../../../interfaces/IPVotingEscrow.sol";

contract FeeDistributorVePendle is PendleFeeDistributorAbstract {
    using Math for uint256;

    address public immutable vePendle;

    constructor(address _vePendle) {
        vePendle = _vePendle;
    }

    function _getUserCheckpointsLength(address user)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return IPVotingEscrow(vePendle).getUserHistoryLength(user);
    }

    function _getUserCheckpointAt(address user, uint256 index)
        internal
        view
        virtual
        override
        returns (Checkpoint memory)
    {
        return IPVotingEscrow(vePendle).getUserHistoryAt(user, index);
    }

    function _getTotalSharesAt(uint256 timestamp)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        assert(WeekMath.isValidWTime(timestamp.Uint128()));
        return IPVotingEscrow(vePendle).totalSupplyAt(uint128(timestamp));
    }

    function _updateGlobalShares() internal virtual override {
        IPVeToken(vePendle).totalSupplyCurrent();
    }
}
