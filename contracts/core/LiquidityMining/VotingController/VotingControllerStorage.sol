// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/IPVeToken.sol";
import "../../../libraries/VeBalanceLib.sol";
import "../../../libraries/math/WeekMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// no reentracy protection yet?
// Should VotingController and stuff become upgradeable?
abstract contract VotingControllerStorage {
    using VeBalanceLib for VeBalance;

    struct PoolInfo {
        uint64 chainId;
        uint128 timestamp;
        VeBalance vote;
    }

    struct UserPoolInfo {
        uint64 weight;
        VeBalance vote;
    }

    uint64 public constant MAX_WEIGHT = 10**18;
    uint128 public constant WEEK = 1 weeks;
    uint128 public constant MAX_LOCK_TIME = 104 weeks;

    uint128 public pendlePerSec;

    // pool infos
    EnumerableSet.AddressSet internal allPools;
    mapping(address => PoolInfo) public poolInfos;

    // [pool, timestamp] => [uint128 vote]
    mapping(address => mapping(uint128 => uint128)) private poolVotesAt;

    // [pool, timestamp] => [uint128 slopechange]
    mapping(address => mapping(uint128 => uint128)) public poolSlopeChangesAt;

    // [chainId] => [pool]
    mapping(uint64 => EnumerableSet.AddressSet) internal chainPools;

    // user voting info
    mapping(address => uint64) public userVotedWeight;

    // [user, pool] => UserPoolInfo
    mapping(address => mapping(address => UserPoolInfo)) public userPoolVotes;

    // user voting checkpoints saved for future feature
    mapping(address => mapping(address => Checkpoint[])) public userPoolCheckpoints;

    // broadcast chain info
    mapping(uint128 => uint128) private totalVotesAt;

    // [pool][timestamp]
    mapping(uint128 => bool) internal isEpochFinalized;

    modifier validateTimestamp(uint128 timestamp) {
        require(
            timestamp == WeekMath.getWeekStartTimestamp(timestamp),
            "not week start timestamp"
        );
        _;
    }

    function getPoolVotesAt(address pool, uint128 timestamp)
        public
        view
        validateTimestamp(timestamp)
        returns (uint128)
    {
        require(poolInfos[pool].timestamp >= timestamp, "pool not updated");
        return poolVotesAt[pool][timestamp];
    }

    function getTotalVotesAt(uint128 timestamp)
        public
        view
        validateTimestamp(timestamp)
        returns (uint128)
    {
        return totalVotesAt[timestamp];
    }

    function _setPoolVoteAt(
        address pool,
        uint128 timestamp,
        uint128 newVote
    ) internal validateTimestamp(timestamp) {
        require(poolVotesAt[pool][timestamp] == 0, "pool vote already recorded");
        totalVotesAt[timestamp] += newVote;
        poolVotesAt[pool][timestamp] = newVote;
    }

    /**
     * @dev There is not a need to call updatePoolVotes on this function
     * If user's vote is not yet expired compared to the pool's timestamp
     * it can be directly subtracted from the pool's vote
     */
    function _removeUserPoolVote(address user, address pool) internal {
        VeBalance memory oldUVote = userPoolVotes[user][pool].vote;
        if (
            _isPoolActive(pool) &&
            oldUVote.slope > 0 &&
            oldUVote.getExpiry() > poolInfos[pool].timestamp
        ) {
            poolInfos[pool].vote = poolInfos[pool].vote.sub(oldUVote);
            poolSlopeChangesAt[pool][oldUVote.getExpiry()] -= oldUVote.slope;
        }

        userVotedWeight[user] -= userPoolVotes[user][pool].weight;
        userPoolVotes[user][pool].weight = 0;
        userPoolVotes[user][pool].vote = VeBalance(0, 0);
    }

    function _setUserVote(
        address user,
        address pool,
        uint64 weight
    ) internal {
        VeBalance memory vote = _getVotingPowerByWeight(user, weight);

        poolInfos[pool].vote = poolInfos[pool].vote.add(vote);
        poolSlopeChangesAt[pool][vote.getExpiry()] += vote.slope;

        userVotedWeight[user] += weight;
        userPoolVotes[user][pool] = UserPoolInfo({ weight: weight, vote: vote });
        userPoolCheckpoints[user][pool].push(
            Checkpoint({ balance: vote, timestamp: uint128(block.timestamp) })
        );
    }

    function _getVotingPowerByWeight(address user, uint64 weight)
        internal
        view
        virtual
        returns (VeBalance memory res);

    function _isPoolActive(address pool) internal view returns (bool) {
        return poolInfos[pool].timestamp != 0;
    }
}
