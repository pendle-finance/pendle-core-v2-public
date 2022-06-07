// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../../interfaces/IPVeToken.sol";
import "../../../libraries/VeBalanceLib.sol";
import "../../../libraries/math/WeekMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// no reentracy protection yet?
// Should VotingController and stuff become upgradeable?
abstract contract VotingControllerStorage {
    using VeBalanceLib for VeBalance;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct PoolInfo {
        uint64 chainId;
        uint128 timestamp;
        VeBalance vote;
        mapping(uint128 => uint128) slopeChanges;
    }

    struct UserPoolInfo {
        uint64 weight;
        VeBalance vote;
    }

    struct UserData {
        uint64 totalVotedWeight;
        mapping(address => UserPoolInfo) voteForPools;
    }

    struct WeekData {
        uint128 totalVotes;
        mapping(address => uint128) poolVotes;
    }

    uint64 public constant MAX_WEIGHT = 10**18;
    uint128 public constant WEEK = 1 weeks;
    uint128 public constant MAX_LOCK_TIME = 104 weeks;

    uint128 public pendlePerSec;

    // pool infos
    EnumerableSet.AddressSet internal allPools;
    mapping(address => PoolInfo) public poolInfos;

    // [timestamp] => WeekData
    mapping(uint128 => WeekData) public weekData;

    // [chainId] => [pool]
    mapping(uint64 => EnumerableSet.AddressSet) internal chainPools;

    // user voting info
    mapping(address => UserData) public userDatas;

    // [pool][timestamp]
    mapping(uint128 => bool) internal isEpochFinalized;

    // [user][pool] => checkpoint
    mapping(address => mapping(address => Checkpoint[])) public userPoolCheckpoints;

    function getPoolVotesAt(address pool, uint128 timestamp) public view returns (uint128) {
        require(timestamp == WeekMath.getWeekStartTimestamp(timestamp), "invalid timestamp");
        require(poolInfos[pool].timestamp >= timestamp, "pool not updated");
        return weekData[timestamp].poolVotes[pool];
    }

    function getTotalVotesAt(uint128 timestamp) public view returns (uint128) {
        require(timestamp == WeekMath.getWeekStartTimestamp(timestamp), "invalid timestamp");
        return weekData[timestamp].totalVotes;
    }

    function getUserPoolVote(address user, address pool)
        public
        view
        returns (UserPoolInfo memory)
    {
        return userDatas[user].voteForPools[pool];
    }

    function _addPool(uint64 chainId, address pool) internal {
        poolInfos[pool].chainId = chainId;
        poolInfos[pool].timestamp = WeekMath.getCurrentWeekStart();
        chainPools[chainId].add(pool);
        allPools.add(pool);
    }

    function _removePool(address pool) internal {
        uint64 chainId = poolInfos[pool].chainId;
        chainPools[chainId].remove(pool);
        allPools.remove(pool);
        delete poolInfos[pool];
    }

    function _setPoolVoteAt(
        address pool,
        uint128 timestamp,
        uint128 vote
    ) internal {
        // THIS WILL NEVER HAPPEN
        // assert(weekData[timestamp].poolVotes[pool] == 0);
        weekData[timestamp].totalVotes += vote;
        weekData[timestamp].poolVotes[pool] = vote;
    }

    function _setPoolVote(address pool, VeBalance memory vote) internal {
        poolInfos[pool].vote = vote;
    }

    function _setPoolTimestamp(address pool, uint128 timestamp) internal {
        poolInfos[pool].timestamp = timestamp;
    }

    function _subtractFromPoolVote(address pool, VeBalance memory vote) internal {
        PoolInfo storage pInfo = poolInfos[pool];
        pInfo.vote = poolInfos[pool].vote.sub(vote);
        pInfo.slopeChanges[vote.getExpiry()] -= vote.slope;
    }

    function _addToPoolVote(address pool, VeBalance memory vote) internal {
        PoolInfo storage pInfo = poolInfos[pool];
        pInfo.vote = poolInfos[pool].vote.add(vote);
        pInfo.slopeChanges[vote.getExpiry()] += vote.slope;
    }

    function _unsetUserPoolVote(address user, address pool) internal {
        UserData storage uData = userDatas[user];
        uData.totalVotedWeight -= uData.voteForPools[pool].weight;
        delete uData.voteForPools[pool];
    }

    function _setUserPoolVote(
        address user,
        address pool,
        uint64 weight,
        VeBalance memory vote
    ) internal {
        UserData storage uData = userDatas[user];
        // THIS WILL NEVER HAPPEN
        // assert(uData.voteForPools[pools].weight == 0);
        uData.totalVotedWeight += weight;
        uData.voteForPools[pool] = UserPoolInfo({ weight: weight, vote: vote });
    }

    function _addUserPoolCheckpoint(
        address user,
        address pool,
        VeBalance memory vote
    ) internal {
        userPoolCheckpoints[user][pool].push(
            Checkpoint({ balance: vote, timestamp: uint128(block.timestamp) })
        );
    }

    function _isPoolActive(address pool) internal view returns (bool) {
        return poolInfos[pool].timestamp != 0;
    }

    function _isVoteActive(VeBalance memory vote) internal view returns (bool) {
        // vote.slope > 0 is a voting controller thing, so this function should not be in
        // VeBalance lib
        return vote.slope > 0 && vote.getExpiry() > block.timestamp;
    }
}
