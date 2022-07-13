// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../../interfaces/IPVeToken.sol";
import "../../../libraries/VeBalanceLib.sol";
import "../../../libraries/math/WeekMath.sol";
import "../../../libraries/helpers/MiniHelpers.sol";
import "../../../libraries/VeHistoryLib.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
abstract contract VotingControllerStorageUpg {
    using VeBalanceLib for VeBalance;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Checkpoints for Checkpoints.History;

    struct PoolData {
        uint64 chainId;
        uint128 lastSlopeChangeAppliedAt;
        VeBalance totalVote;
        // wTime => slopeChange value
        mapping(uint128 => uint128) slopeChanges;
    }

    struct UserPoolData {
        uint64 weight;
        VeBalance vote;
    }

    struct UserData {
        uint64 totalVotedWeight;
        mapping(address => UserPoolData) voteForPools;
    }

    struct WeekData {
        bool isEpochFinalized;
        uint128 totalVotes;
        mapping(address => uint128) poolVotes;
    }

    uint128 public constant MAX_LOCK_TIME = 104 weeks;
    uint64 public constant USER_VOTE_MAX_WEIGHT = 10**18;
    uint128 public constant WEEK = 1 weeks;
    uint128 public constant GOVERNANCE_PENDLE_VOTE = 10**24;

    IPVeToken public immutable vePendle;

    uint128 public immutable deployedWTime;

    uint128 public pendlePerSec;

    EnumerableSet.AddressSet internal allActivePools;

    EnumerableSet.AddressSet internal allRemovedPools;

    // [chainId] => [pool]
    mapping(uint64 => EnumerableSet.AddressSet) internal chainPools;

    // [poolAddress] -> PoolData
    mapping(address => PoolData) public poolData;

    // [wTime] => WeekData
    mapping(uint128 => WeekData) public weekData;

    // user voting data
    mapping(address => UserData) public userData;

    // [user][pool] => checkpoint
    mapping(address => mapping(address => Checkpoints.History)) internal userPoolHistory;

    uint256[100] private __gap;

    constructor(address _vePendle) {
        vePendle = IPVeToken(_vePendle);
        deployedWTime = WeekMath.getCurrentWeekStart();
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev trivial view function
    function getAllAcitvePools() external view returns (address[] memory) {
        return allActivePools.values();
    }

    /// @dev trivial view function
    function getAllRemovedPools(uint256 start, uint256 end)
        external
        view
        returns (uint256 lengthOfRemovedPools, address[] memory arr)
    {
        arr = new address[](end - start + 1);
        for (uint256 i = start; i <= end; i++) arr[i] = allRemovedPools.at(i);
        lengthOfRemovedPools = allRemovedPools.length();
    }

    /// @dev trivial view function
    function getChainPools(uint64 chainId) external view returns (address[] memory) {
        return chainPools[chainId].values();
    }

    /// @dev trivial view function
    function getUserPoolVote(address user, address pool)
        external
        view
        returns (UserPoolData memory)
    {
        return userData[user].voteForPools[pool];
    }

    /**
     * @dev binary search to get the vote of an user on a pool at a specific timestamp
     * @param timestamp can be any time, not necessary divisible by week
     */
    function getUserPoolVoteAt(
        address user,
        address pool,
        uint128 timestamp
    ) external view returns (uint128) {
        return userPoolHistory[user][pool].getAtTimestamp(timestamp);
    }

    /*///////////////////////////////////////////////////////////////
                            INTERNAL DATA MANIPULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
    * @dev expected behavior:
        - add to allPools, chainPools
        - set params in poolData
     */
    function _addPool(uint64 chainId, address pool) internal {
        require(chainPools[chainId].add(pool), "IE");
        require(allActivePools.add(pool), "IE");

        poolData[pool].chainId = chainId;
        poolData[pool].lastSlopeChangeAppliedAt = WeekMath.getCurrentWeekStart();
    }

    /**
    * @dev expected behavior:
        - remove from allPools, chainPools
        - clear all params in poolData
     */
    function _removePool(address pool) internal {
        uint64 chainId = poolData[pool].chainId;
        require(chainPools[chainId].remove(pool), "IE");
        require(allActivePools.remove(pool), "IE");
        require(allRemovedPools.add(pool), "IE");

        delete poolData[pool];
    }

    /**
     * @notice set the final pool vote for weekData
     * @dev assumption: weekData[wTime].poolVotes[pool] == 0
     */
    function _setFinalPoolVoteForWeek(
        address pool,
        uint128 wTime,
        uint128 vote
    ) internal {
        weekData[wTime].totalVotes += vote;
        weekData[wTime].poolVotes[pool] = vote;
    }

    function _setNewVotePoolData(
        address pool,
        VeBalance memory vote,
        uint128 wTime
    ) internal {
        poolData[pool].totalVote = vote;
        poolData[pool].lastSlopeChangeAppliedAt = wTime;
    }

    function _modifyVoteWeight(
        address user,
        address pool,
        uint64 weight
    ) internal returns (VeBalance memory newVote) {
        UserData storage uData = userData[user];
        PoolData storage pData = poolData[pool];

        VeBalance memory oldVote = uData.voteForPools[pool].vote;

        // REMOVE OLD VOTE
        if (oldVote.bias != 0) {
            if (_isPoolVotable(pool) && _isVoteActive(oldVote)) {
                pData.totalVote = pData.totalVote.sub(oldVote);
                pData.slopeChanges[oldVote.getExpiry()] -= oldVote.slope;
            }
            uData.totalVotedWeight -= uData.voteForPools[pool].weight;
            delete uData.voteForPools[pool];
        }

        // ADD NEW VOTE
        if (weight != 0) {
            require(_isPoolVotable(pool), "pool not votable");

            newVote = _getVotingPowerByWeight(user, weight);

            pData.totalVote = pData.totalVote.add(newVote);
            pData.slopeChanges[newVote.getExpiry()] += newVote.slope;

            uData.voteForPools[pool] = UserPoolData(weight, newVote);
            uData.totalVotedWeight += weight;
            require(uData.totalVotedWeight <= USER_VOTE_MAX_WEIGHT, "exceeded max weight");
        }

        userPoolHistory[user][pool].push(newVote);
    }

    function _setAllPastEpochsAsFinalized() internal {
        uint128 wTime = WeekMath.getCurrentWeekStart();
        while (wTime >= deployedWTime && weekData[wTime].isEpochFinalized == false) {
            weekData[wTime].isEpochFinalized = true;
            wTime -= WEEK;
        }
    }

    /// @notice check if a pool is votable on by checking the lastSlopeChangeAppliedAt time
    function _isPoolVotable(address pool) internal view returns (bool) {
        return allActivePools.contains(pool);
    }

    /// @notice check if a vote still counts by checking if the vote is not (x,0) (in case the
    /// weight of the vote is too small) & the expiry is after the current time
    function _isVoteActive(VeBalance memory vote) internal view returns (bool) {
        return vote.slope != 0 && !MiniHelpers.isCurrentlyExpired(vote.getExpiry());
    }

    function _getVotingPowerByWeight(address user, uint64 weight)
        internal
        view
        virtual
        returns (VeBalance memory res);
}
