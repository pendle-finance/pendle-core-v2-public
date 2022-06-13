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

    uint64 public constant USER_VOTE_MAX_WEIGHT = 10**18;

    struct PoolInfo {
        uint64 chainId;
        uint128 lastUpdated;
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

    EnumerableSet.AddressSet internal allPools;

    // [chainId] => [pool]
    mapping(uint64 => EnumerableSet.AddressSet) internal chainPools;

    // [poolAddress] -> PoolInfo
    mapping(address => PoolInfo) public poolInfo;

    // [timestamp] => WeekData
    mapping(uint128 => WeekData) public weekData;

    // user voting info
    mapping(address => UserData) public userData;

    // [pool][timestamp]
    mapping(uint128 => bool) public isEpochFinalized;

    // [user][pool] => checkpoint
    mapping(address => mapping(address => Checkpoint[])) public userPoolCheckpoints;

    function getAllPools() public view returns (address[] memory) {
        return allPools.values();
    }

    function getChainPools(uint64 chainId) public view returns (address[] memory) {
        return chainPools[chainId].values();
    }

    function getPoolVotesAt(address pool, uint128 timestamp) public view returns (uint128) {
        require(timestamp == WeekMath.getWeekStartTimestamp(timestamp), "invalid timestamp");
        require(poolInfo[pool].lastUpdated >= timestamp, "pool not updated");
        return weekData[timestamp].poolVotes[pool];
    }

    function getTotalVotesAt(uint128 timestamp) public view returns (uint128) {
        require(timestamp == WeekMath.getWeekStartTimestamp(timestamp), "invalid timestamp");
        return weekData[timestamp].totalVotes;
    }

    function getUserPoolVote(address user, address pool)
        external
        view
        returns (UserPoolInfo memory)
    {
        return userData[user].voteForPools[pool];
    }

    function getUserPoolVoteAt(
        address user,
        address pool,
        uint128 timestamp
    ) external view returns (uint128) {
        return VeBalanceLib.getCheckpointValueAt(userPoolCheckpoints[user][pool], timestamp);
    }

    /**
    * @dev expected behavior:
        - add to allPools, chainPools
        - set params in poolInfo
     */
    function _addPool(uint64 chainId, address pool) internal {
        poolInfo[pool].chainId = chainId;
        poolInfo[pool].lastUpdated = WeekMath.getCurrentWeekStart();
        require(chainPools[chainId].add(pool), "IE: chainPools duplicated");
        require(allPools.add(pool), "IE: allPools duplicated");
    }

    /**
    * @dev expected behavior:
        - remove from allPools, chainPools
        - clear all params in poolInfo
     */
    function _removePool(address pool) internal {
        uint64 chainId = poolInfo[pool].chainId;
        require(chainPools[chainId].remove(pool), "IE: chainPools removal failed");
        require(allPools.remove(pool), "IE: allPools removal failed");
        delete poolInfo[pool];
    }

    /**
     * @notice set the final pool vote for weekData
     * @dev assumption: weekData[timestamp].poolVotes[pool] == 0
     */
    function _setFinalPoolVoteForWeek(
        address pool,
        uint128 timestamp,
        uint128 vote
    ) internal {
        weekData[timestamp].totalVotes += vote;
        weekData[timestamp].poolVotes[pool] = vote;
    }

    /// @dev assumption: poolInfo[pool].vote == 0
    function _setPoolVote(address pool, VeBalance memory vote) internal {
        poolInfo[pool].vote = vote;
    }

    /// @dev assumption: poolInfo[pool].vote == 0
    function _setPoolLastUpdated(address pool, uint128 timestamp) internal {
        poolInfo[pool].lastUpdated = timestamp;
    }

    /// @dev only applicable for current pool, hence no changes for weekData
    function _subtractFromPoolVote(address pool, VeBalance memory vote) internal {
        PoolInfo storage pInfo = poolInfo[pool];
        pInfo.vote = poolInfo[pool].vote.sub(vote);
        pInfo.slopeChanges[vote.getExpiry()] -= vote.slope;
    }

    /// @dev only applicable for current pool, hence no changes for weekData
    function _addToPoolVote(address pool, VeBalance memory vote) internal {
        PoolInfo storage pInfo = poolInfo[pool];
        pInfo.vote = poolInfo[pool].vote.add(vote);
        pInfo.slopeChanges[vote.getExpiry()] += vote.slope;
    }

    function _unsetUserPoolVote(address user, address pool) internal {
        UserData storage uData = userData[user];
        uData.totalVotedWeight -= uData.voteForPools[pool].weight;
        delete uData.voteForPools[pool];
    }

    /// @dev assumption: uData.voteForPools[pool] hasn't been set before
    /// @dev post-condition: totalVotedWeight <= USER_VOTE_MAX_WEIGHT
    function _setUserPoolVote(
        address user,
        address pool,
        uint64 weight,
        VeBalance memory vote
    ) internal {
        UserData storage uData = userData[user];
        uData.totalVotedWeight += weight;
        require(uData.totalVotedWeight <= USER_VOTE_MAX_WEIGHT, "exceeded max weight");

        uData.voteForPools[pool] = UserPoolInfo({ weight: weight, vote: vote });
    }

    /// @dev post-condition: timestamp is in increasing order (for binary search)
    function _addUserPoolCheckpoint(
        address user,
        address pool,
        VeBalance memory vote
    ) internal {
        userPoolCheckpoints[user][pool].push(
            Checkpoint({ balance: vote, timestamp: uint128(block.timestamp) })
        );
    }

    /// @notice check if a pool is votable on by checking the lastUpdated time
    function _isPoolVotable(address pool) internal view returns (bool) {
        return poolInfo[pool].lastUpdated != 0;
    }

    /// @notice check if a vote still counts by checking if the vote is not (x,0) (in case the
    /// weight of the vote is too small) & the expiry is after the current time
    function _isVoteActive(VeBalance memory vote) internal view returns (bool) {
        return vote.slope != 0 && block.timestamp < vote.getExpiry();
    }
}
