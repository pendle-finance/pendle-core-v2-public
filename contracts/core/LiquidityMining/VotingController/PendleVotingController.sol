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
        require(!_isPoolActive(pool), "pool already added");
        poolInfos[pool] = PoolInfo({
            chainId: chainId,
            timestamp: WeekMath.getCurrentWeekStartTimestamp(),
            vote: VeBalance(0, 0)
        });
        chainPools[chainId].add(pool);
        allPools.add(pool);
    }

    function removePool(address pool) external onlyGovernance {
        require(_isPoolActive(pool), "invalid pool");
        uint64 chainId = poolInfos[pool].chainId;
        chainPools[chainId].remove(pool);
        allPools.remove(pool);
        poolInfos[pool] = PoolInfo(0, 0, VeBalance(0, 0));
    }

    function vote(address pool, uint64 weight) external {
        require(weight != 0, "zero weight");
        require(_isPoolActive(pool), "invalid pool");
        require(!vePendle.isPositionExpired(msg.sender), "user position expired");

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

    function getPoolVotesCurrentEpoch(address pool) public view returns (uint256) {
        require(_isPoolActive(pool), "invalid pool");
        uint128 timestamp = poolInfos[pool].timestamp;
        uint128 currentWeekStart = WeekMath.getCurrentWeekStartTimestamp();

        VeBalance memory votes = poolInfos[pool].vote;
        while (timestamp < currentWeekStart) {
            timestamp += WEEK;
            votes = votes.sub(poolSlopeChangesAt[pool][timestamp], timestamp);
        }
        return votes.getValueAt(timestamp);
    }

    function updatePoolVotes(address pool) public {
        uint128 timestamp = poolInfos[pool].timestamp;
        uint128 currentWeekStart = WeekMath.getCurrentWeekStartTimestamp();

        require(_isPoolActive(pool), "invalid pool");

        if (timestamp >= currentWeekStart) {
            return;
        }

        VeBalance memory votes = poolInfos[pool].vote;
        while (timestamp < currentWeekStart) {
            timestamp += WEEK;
            votes = votes.sub(poolSlopeChangesAt[pool][timestamp], timestamp);
            _setPoolVoteAt(pool, timestamp, votes.getValueAt(timestamp));
        }
        poolInfos[pool].vote = votes;
        poolInfos[pool].timestamp = timestamp;
    }

    function finalizeVotingResults() external {
        uint128 timestamp = WeekMath.getCurrentWeekStartTimestamp();
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
        uint128 timestamp = WeekMath.getCurrentWeekStartTimestamp();
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

    function _getVotingPowerByWeight(address user, uint64 weight)
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
            expiry = WeekMath.getWeekStartTimestamp(uint128(block.timestamp) + MAX_LOCK_TIME);
        } else {
            (amount, expiry) = vePendle.positionData(user);
        }

        (res.bias, res.slope) = vePendle.convertToVeBalance(
            uint128((uint256(amount) * weight) / MAX_WEIGHT),
            expiry
        );
    }

    function _broadcastVotingResults(
        uint64 chainId,
        uint128 timestamp,
        uint128 pendlePerSec
    ) internal {
        uint256 length = chainPools[chainId].length();
        address[] memory pools = chainPools[chainId].values();
        uint256[] memory incentives = new uint256[](length);

        uint256 totalVotes = getTotalVotesAt(timestamp);
        if (totalVotes == 0) {
            return;
        }

        for (uint256 i = 0; i < length; ++i) {
            // poolVotes can be as large as pendle supply ~ 1e27
            // pendle per sec can be as large as 1e20
            // casting to uint256 here to prevent overflow
            uint256 pendleSpeed = (uint256(pendlePerSec) * getPoolVotesAt(pools[i], timestamp)) /
                totalVotes;
            incentives[i] = pendleSpeed * WEEK;
        }

        if (chainId == block.chainid) {
            address gaugeController = sidechainContracts.get(uint256(chainId));
            IPGaugeControllerMainchain(gaugeController).updateVotingResults(
                timestamp,
                pools,
                incentives
            );
        } else {
            _sendMessage(chainId, abi.encode(timestamp, pools, incentives));
        }
    }
}
