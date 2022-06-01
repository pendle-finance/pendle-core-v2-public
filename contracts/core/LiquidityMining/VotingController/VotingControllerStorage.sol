// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../../interfaces/IPVeToken.sol";
import "../../../libraries/VeBalanceLib.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// no reentracy protection yet?
// Should VotingController and stuff become upgradeable?
abstract contract VotingControllerStorage {
    using VeBalanceLib for VeBalance;

    struct PoolInfo {
        uint128 timestamp;
        uint64 chainId;
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

    // [pool] => [VeBalance vote]
    mapping(address => VeBalance) public poolVotes;

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
        require(timestamp % WEEK == 0, "invalid timestamp");
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
        if (oldUVote.slope > 0 && oldUVote.getExpiry() > poolInfos[pool].timestamp) {
            poolVotes[pool] = poolVotes[pool].sub(oldUVote);
            poolSlopeChangesAt[pool][oldUVote.getExpiry()] -= oldUVote.slope;
        }

        userVotedWeight[user] -= userPoolVotes[user][pool].weight;
        userPoolVotes[user][pool].weight = 0;
    }

    function _setUserVote(
        address user,
        address pool,
        uint64 weight
    ) internal {
        require(userPoolVotes[user][pool].weight == 0, "vote already set");
        VeBalance memory vote = _getUserBalanceByWeight(user, weight);

        poolVotes[pool] = poolVotes[pool].add(vote);
        poolSlopeChangesAt[pool][vote.getExpiry()] += vote.slope;

        userVotedWeight[user] += weight;
        userPoolVotes[user][pool] = UserPoolInfo({ weight: weight, vote: vote });
        userPoolCheckpoints[user][pool].push(
            Checkpoint({ balance: vote, timestamp: uint128(block.timestamp) })
        );
    }

    function _getUserBalanceByWeight(address user, uint64 weight)
        internal
        view
        virtual
        returns (VeBalance memory res);
}
