// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./VotingControllerStorageUpg.sol";
import "../CelerAbstracts/CelerSenderUpg.sol";
import "../../../libraries/VeBalanceLib.sol";
import "../../../libraries/math/Math.sol";
import "../../../interfaces/IPGaugeControllerMainchain.sol";
import "../../../interfaces/IPVotingController.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

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

/// This contract is upgradable because
/// - its constructor only sets immutable variables
/// - it has storage gaps for safe addition of future variables
/// - it inherits only upgradable contract
contract PendleVotingControllerUpg is
    CelerSenderUpg,
    VotingControllerStorageUpg,
    UUPSUpgradeable,
    IPVotingController
{
    using VeBalanceLib for VeBalance;
    using Math for uint256;
    using Math for int256;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address _vePendle, address _governanceManager)
        VotingControllerStorageUpg(_vePendle) // constructor only set immutable variables
        CelerSenderUpg(_governanceManager) // constructor only set immutable variables
    {}

    /*///////////////////////////////////////////////////////////////
                FUNCTIONS CAN BE CALLED BY ANYONE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev state changes expected:
        - update weekData (if any)
        - update poolData, userData to reflect the new vote
        - add 1 check point for each of pools
     * @dev vePENDLE position not expired is a must, else bias - t*slope < 0 & it will be
        negative weight
     */
    function vote(address[] calldata pools, uint64[] calldata weights) external {
        address user = msg.sender;

        require(weights.length == pools.length, "invaid array length");
        require(vePendle.balanceOf(user) > 0, "zero vependle balance");

        UserData storage uData = userData[user];

        for (uint256 i = 0; i < pools.length; ++i) {
            if (_isPoolActive(pools[i])) applyPoolSlopeChanges(pools[i]);
        }

        for (uint256 i = 0; i < pools.length; ++i) {
            if (uData.voteForPools[pools[i]].weight <= weights[i])
                _modifyVoteWeight(user, pools[i], weights[i]);
        }

        for (uint256 i = 0; i < pools.length; ++i) {
            if (uData.voteForPools[pools[i]].weight > weights[i])
                _modifyVoteWeight(user, pools[i], weights[i]);
        }
    }

    /**
     * @notice Process all the slopeChanges that haven't been processed & update these data into
        poolData
     * @dev pre-condition: the pool must be active
     * @dev state changes expected:
        - update weekData
        - update poolData
     */
    function applyPoolSlopeChanges(address pool) public {
        require(_isPoolActive(pool), "invalid pool");

        uint128 wTime = poolData[pool].lastSlopeChangeAppliedAt;
        uint128 currentWeekStart = WeekMath.getCurrentWeekStart();

        // no state changes are expected
        if (wTime >= currentWeekStart) return;

        VeBalance memory currentVote = poolData[pool].totalVote;
        while (wTime < currentWeekStart) {
            wTime += WEEK;
            currentVote = currentVote.sub(poolData[pool].slopeChanges[wTime], wTime);
            _setFinalPoolVoteForWeek(pool, wTime, currentVote.getValueAt(wTime));
        }

        _setNewVotePoolData(pool, currentVote, wTime);
    }

    /**
     * @notice finalize the voting results of all pools, up to the current epoch
     * @dev state changes expected:
        - weekData, poolData is updated for all pools in allActivePools
        - isEpochFinalized is set to true for all epochs since the last time until now
     * @dev this function might take a lot of gas, but can be mitigated by calling applyPoolSlopeChanges
        separately, hence reduce the number of states to be updated
     */
    function finalizeEpoch() public {
        uint256 length = allActivePools.length();
        for (uint256 i = 0; i < length; ++i) {
            applyPoolSlopeChanges(allActivePools.at(i));
        }
        _setAllPastEpochsAsFinalized();
    }

    /**
     * @notice broadcast the voting results of the current week to the chain with chainId. Can be
        called by anyone
     * @dev pre-condition: the epoch must have already been finalized by finalizeEpoch
     * @dev state changes expected:
        - the gaugeController receives the new pendle allocation
     */
    function broadcastResults(uint64 chainId) external payable {
        uint128 wTime = WeekMath.getCurrentWeekStart();
        require(weekData[wTime].isEpochFinalized, "epoch not finalized");
        _broadcastResults(chainId, wTime, pendlePerSec);
    }

    /*///////////////////////////////////////////////////////////////
                    GOVERNANCE-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice add a pool to allow users to vote. Can only be done by governance
     * @dev pre-condition: pool must not have been added before
     * @dev assumption: chainId is valid, pool does exist on the chain (guaranteed by gov)
     * @dev state changes expected:
        - add to allActivePools & chainPools
        - set params in poolData
     */
    function addPool(uint64 chainId, address pool) external onlyGovernance {
        require(!_isPoolActive(pool), "pool already added");
        require(!allRemovedPools.contains(pool), "not allowed to add a removed pool");

        _addPool(chainId, pool);
        emit AddPool(chainId, pool);
    }

    /**
     * @notice remove a pool from voting. Can only be done by governance
     * @dev pre-condition: pool must have been added before
     * @dev state changes expected:
        - update weekData (if any)
        - remove from allActivePools & chainPools
        - clear data in poolData
     */
    function removePool(address pool) external onlyGovernance {
        require(_isPoolActive(pool), "invalid pool");

        uint64 chainId = poolData[pool].chainId;

        applyPoolSlopeChanges(pool);
        _removePool(pool);

        emit RemovePool(chainId, pool);
    }

    /**
     * @notice use the gov-privilege to force broadcast a message in case there are issues with Celer
     * @dev it's intentional for this function to have minimal checks since we assume gov has done the
        due dilligence
     * @dev gov should always call finalizeEpoch beforehand
     * @dev state changes expected:
        - the gaugeController receives the new pendle allocation
     */
    function forceBroadcastResults(
        uint64 chainId,
        uint128 wTime,
        uint128 forcedPendlePerSec
    ) external payable onlyGovernance {
        _broadcastResults(chainId, wTime, forcedPendlePerSec);
    }

    /**
     * @notice set new pendlePerSec
     * @dev no zero checks because gov may want to stop liquidity mining
     * @dev state changes expected: pendlePerSec is updated
     */
    function setPendlePerSec(uint128 newPendlePerSec) external onlyGovernance {
        pendlePerSec = newPendlePerSec;
        emit SetPendlePerSec(newPendlePerSec);
    }

    /*///////////////////////////////////////////////////////////////
                    INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice broadcast voting results of the timestamp to chainId
     * @dev assumption: the epoch is already finalized, lastSlopeChangeAppliedAt of all pools >= currentWeekTimestamp
     * @dev state changes expected:
        - the gaugeController receives the new pendle allocation
     */
    function _broadcastResults(
        uint64 chainId,
        uint128 wTime,
        uint128 totalPendlePerSec
    ) internal {
        uint256 totalVotes = weekData[wTime].totalVotes;
        if (totalVotes == 0) return;

        uint256 length = chainPools[chainId].length();
        if (length == 0) return;

        address[] memory pools = chainPools[chainId].values();
        uint256[] memory totalPendleAmounts = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            uint256 poolVotes = weekData[wTime].poolVotes[pools[i]];
            uint256 pendlePerSec = (uint256(totalPendlePerSec) * poolVotes) / totalVotes;
            totalPendleAmounts[i] = pendlePerSec * WEEK;
        }

        if (chainId == block.chainid) {
            address gaugeController = sidechainContracts.get(uint256(chainId));
            IPGaugeControllerMainchain(gaugeController).updateVotingResults(
                wTime,
                pools,
                totalPendleAmounts
            );
        } else {
            _sendMessage(chainId, abi.encode(wTime, pools, totalPendleAmounts));
        }

        emit BroadcastResults(chainId, wTime, totalPendlePerSec);
    }

    /**
     * @notice return the corresponding voting power of an user given the weight. Basically his voting power
        will be vePendle * weight / USER_VOTE_MAX_WEIGHT
     * @notice governance will always has the vePendle equivalent to 1M PENDLE locked for MAX_LOCK_TIME
     */
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

        (res.bias, res.slope) = VeBalanceLib.convertToVeBalance(
            uint128((uint256(amount) * weight) / USER_VOTE_MAX_WEIGHT),
            expiry
        );
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyGovernance {}
}
