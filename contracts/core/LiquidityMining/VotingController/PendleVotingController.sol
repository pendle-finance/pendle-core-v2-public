// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./VotingControllerStorage.sol";
import "../CelerAbstracts/CelerSender.sol";
import "../../../libraries/VeBalanceLib.sol";
import "../../../libraries/math/Math.sol";
import "../../../interfaces/IPGaugeControllerMainchain.sol";

// no reentracy protection yet?
// Should VotingController and stuff become upgradeable?


/*
Voting accounting:
    - For gauge controller, it will consider each message from voting controller
    as a pack of money to incentivize it during the very next WEEK (block.timestamp -> block.timestamp + WEEK)
    - If the reward duration for the last pack of money has not ended, it will combine
    the leftover reward with the current reward to distribute.

    - In the very extreme case where no one broadcast the result of week x, and at week x+1, 
    the results for both are now broadcasted, then the WEEK of (block.timestamp -> WEEK) 
    will receive both of the reward pack
    - Each pack of money will has it own id as timestamp, a gauge controller does not
    receive a pack of money with the same id twice, this allow governance to rebroadcast
    in case the last message was corrupted by Celer

Pros:
    - If governance does not forget broadcasting the reward on the early of the week,
    the mechanism works just the same as the epoch-based one
    - If governance forget to broadcast the reward, the whole system still works normally,
    the reward is still incentivized, but only approximately fair
Cons:
    - Does not guarantee the reward will be distributed on epoch start and end
*/

contract PendleVotingController is CelerSender, VotingControllerStorage {
    using VeBalanceLib for VeBalance;
    using Math for uint256;
    using Math for int256;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint128 public constant GOVERNANCE_PENDLE_VOTE = 10**24;
    IPVeToken public immutable vePendle;

    constructor(address _vePendle, address _governanceManager) CelerSender(_governanceManager) {
        vePendle = IPVeToken(_vePendle);
    }

    function addPool(uint64 chainId, address pool) external onlyGovernance {
        require(poolInfos[pool].timestamp == 0, "pool already added");
        poolInfos[pool] = PoolInfo({ chainId: chainId, timestamp: _getCurrentEpochStart() });
        chainPools[chainId].add(pool);
        allPools.add(pool);
    }

    function removePool(address pool) external onlyGovernance {
        require(poolInfos[pool].timestamp != 0, "invalid pool");
        uint64 chainId = poolInfos[pool].chainId;
        chainPools[chainId].remove(pool);
        allPools.remove(pool);
        poolInfos[pool] = PoolInfo(0, 0);
    }

    function vote(address pool, uint64 weight) external {
        require(poolInfos[pool].timestamp != 0, "invalid pool");
        address user = msg.sender;
        _removeUserPoolVote(user, pool);
        _setUserVote(user, pool, weight);
    }

    function removeVote(address pool) external {
        // Not unactive, inactive
        // good idea: All operations that require touching multiple mapping together, should be done through functions
        // Idea of separating storage contract from logic is not new, but interesting
        _removeUserPoolVote(msg.sender, pool);
    }

    /**
     * @dev This function is aimed to be used by broadcast function, which will broadcast every pool
     * at once. So it is implemented so that no SSTORE is executed to save gas for broadcasting.
     *
     * @dev the updating code seems reusable by two functions getCurrentPoolVotes and updatePoolVotes
     * But one of them should be view, and the other should update the checkpoint for poolVote
     * on every of its iteration. Therefore, reusing code here is not possible.
     */
    function getPoolVotesCurrentEpoch(address pool) public view returns (uint256) {
        uint128 timestamp = poolInfos[pool].timestamp;
        require(timestamp != 0, "invalid pool");

        VeBalance memory votes = poolVotes[pool];
        while (timestamp + WEEK <= block.timestamp) {
            timestamp += WEEK;
            votes = votes.sub(poolSlopeChangesAt[pool][timestamp], timestamp);
        }
        return votes.getValueAt(timestamp);
    }

    function updatePoolVotes(address pool) public {
        uint128 timestamp = poolInfos[pool].timestamp;
        require(timestamp != 0, "invalid pool");

        if (timestamp + WEEK > block.timestamp) {
            return;
        }

        VeBalance memory votes = poolVotes[pool];
        while (timestamp + WEEK <= block.timestamp) {
            timestamp += WEEK;
            votes = votes.sub(poolSlopeChangesAt[pool][timestamp], timestamp);
            _setPoolVoteAt(pool, timestamp, votes.getValueAt(timestamp));
        }
        poolVotes[pool] = votes;
        poolInfos[pool].timestamp = timestamp;
    }

    function finalizeVotingResults(uint128 timestamp) external validateTimestamp(timestamp) {
        require(timestamp <= _getCurrentEpochStart(), "invalid timestamp");
        uint256 length = allPools.length();
        for (uint256 i = 0; i < length; ++i) {
            address pool = allPools.at(i);
            if (poolInfos[pool].timestamp < timestamp) {
                updatePoolVotes(pool);
            }
        }
        isEpochFinalized[timestamp] = true;
    }

    function broadcastVotingResults(uint64 chainId) external payable {
        uint128 timestamp = _getCurrentEpochStart();
        require(isEpochFinalized[timestamp], "epoch not finalized");
        _broadcastVotingResults(chainId, timestamp, pendlePerSec);
    }

    function forceBroadcastResults(
        uint64 chainId,
        uint128 timestamp,
        uint128 forcedPendlePerSec
    ) external payable onlyGovernance {
        require(isEpochFinalized[timestamp], "epoch not finalized");
        _broadcastVotingResults(chainId, timestamp, forcedPendlePerSec);
    }

    function setPendlePerSec(uint128 newPendlePerSec) external onlyGovernance {
        pendlePerSec = newPendlePerSec;
    }

    function _getCurrentEpochStart() internal view returns (uint128) {
        return (uint128(block.timestamp) / WEEK) * WEEK;
    }

    function _getUserBalanceByWeight(address user, uint64 weight)
        internal
        view
        virtual
        override
        returns (VeBalance memory res)
    {
        uint128 amount;
        uint128 expiry;

        if (user == _governance()) {
            amount = GOVERNANCE_PENDLE_VOTE;
            expiry = ((uint128(block.timestamp) + MAX_LOCK_TIME) / WEEK) * WEEK;
        } else {
            (amount, expiry) = vePendle.positionData(user);
        }
        
        require(expiry > block.timestamp, "user position expired");
        amount = (amount * uint128(weight)) / MAX_WEIGHT / MAX_LOCK_TIME;
        res.slope = amount;
        res.bias = amount * expiry;
    }

    function _broadcastVotingResults(
        uint64 chainId,
        uint128 timestamp,
        uint128 pendlePerSec
    ) internal {
        uint256 length = chainPools[chainId].length();
        address[] memory pools = chainPools[chainId].values();
        uint256[] memory incentives = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            // poolVotes can be as large as pendle supply ~ 1e27
            // pendle per sec can be as large as 1e20
            // casting to uint256 here to prevent overflow
            uint256 pendleSpeed = (uint256(pendlePerSec) * getPoolVotesAt(pools[i], timestamp)) /
                getTotalVotesAt(timestamp);
            incentives[i] = pendleSpeed * WEEK;
        }

        if (chainId == block.chainid) {
            address gaugeController = sidechainContracts.get(uint256(chainId));
            IPGaugeControllerMainchain(gaugeController).updateVotingResults(timestamp, pools, incentives);
        } else {
            _sendMessage(chainId, abi.encode(timestamp, pools, incentives));
        }
    }
}
