// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../libraries/VeBalanceLib.sol";
import "../../libraries/math/Math.sol";

import "../../interfaces/IPVeToken.sol";
import "../../interfaces/IPGaugeControllerMainchain.sol";
import "./CelerAbstracts/CelerSender.sol";

contract PendleVotingController is CelerSender {
    using VeBalanceLib for VeBalance;
    using Math for uint256;
    using Math for int256;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    struct PoolInfo {
        uint256 chainId;
        address market;
        bool active;
        uint256 weight;
        uint256 timestamp;
    }

    struct UserPoolInfo {
        uint256 weight;
        VeBalance vote;
    }

    uint256 public constant WEEK = 1 weeks;
    uint256 public constant MAX_WEIGHT = 10**9;
    uint256 public constant MAX_LOCK_TIME = 104 weeks;

    IPVeToken public immutable vePendle;
    uint256 public pendlePerSec;

    // pool infos
    PoolInfo[] public allPools;
    mapping(uint256 => uint256[]) public chainPools;
    mapping(uint256 => mapping(address => bool)) public poolExists;

    // pool votes
    mapping(uint256 => VeBalance) public poolVotes;
    mapping(uint256 => mapping(uint256 => uint256)) public poolVotesAt;
    mapping(uint256 => mapping(uint256 => uint256)) public poolSlopeChangesAt;

    // a pool's final vote is its total vote multiplied by weight
    // weight can be set by governance, valued in range [80, 120] and 100 by default
    mapping(uint256 => uint256) public poolWeight;

    // user voting info
    mapping(address => uint256) public userVotedWeight;
    mapping(address => mapping(uint256 => UserPoolInfo)) public userPoolVotes;

    // user voting checkpoints saved for future feature
    mapping(address => mapping(uint256 => Checkpoint[])) public userPoolCheckpoints;

    // broadcast chain info
    mapping(uint256 => bool) public epochBroadcasted;

    constructor(address _vePendle, address _governanceManager) CelerSender(_governanceManager) {
        vePendle = IPVeToken(_vePendle);
    }

    function addPool(uint256 chainId, address market) external onlyGovernance {
        require(!poolExists[chainId][market], "pool already added");
        uint256 poolId = allPools.length;
        allPools.push(
            PoolInfo({
                chainId: chainId,
                market: market,
                active: true,
                weight: 100,
                timestamp: _getCurrentEpochStart()
            })
        );
        chainPools[chainId].push(poolId);
        poolExists[chainId][market] = true;
    }

    function removePool(uint256 poolId) external onlyGovernance {
        require(allPools[poolId].active, "pool not active");
        uint256 chainId = allPools[poolId].chainId;
        address market = allPools[poolId].market;
        poolExists[chainId][market] = false;
        allPools[poolId].active = false;

        uint256[] storage cpools = chainPools[chainId];
        for (uint256 i = 0; i < cpools.length; ++i) {
            if (cpools[i] == poolId) {
                cpools[i] = cpools[cpools.length - 1];
                cpools.pop();
                break;
            }
        }

        assert(false); // this should never happen
    }

    function setPoolWeight(uint256 poolId, uint256 newWeight) external onlyGovernance {
        require(allPools[poolId].active, "pool not active");
        require(newWeight >= 80 && newWeight <= 120, "invalid weight");
        allPools[poolId].weight = newWeight;
    }

    // weight can be negative
    function vote(uint256 poolId, int256 weight) external {
        require(allPools[poolId].active, "pool not active");

        address user = msg.sender;
        updatePoolVotes(poolId);

        // Remove old vote
        VeBalance memory pvotes = poolVotes[poolId];
        VeBalance memory oldUVote = userPoolVotes[user][poolId].vote;
        if (oldUVote.isValid()) {
            pvotes = pvotes.sub(oldUVote);
            poolSlopeChangesAt[poolId][oldUVote.getExpiry()] -= oldUVote.slope;
        }

        userVotedWeight[user] = (userVotedWeight[user].Int() + weight).Uint();
        require(userVotedWeight[user] <= MAX_WEIGHT, "max weight exceed");

        uint256 newUWeight = (userPoolVotes[user][poolId].weight.Int() + weight).Uint();
        VeBalance memory newUVote = _getUserBalanceByWeight(user, newUWeight);

        // Update pool Info
        poolVotes[poolId] = pvotes.add(newUVote);
        if (newUVote.isValid()) {
            poolSlopeChangesAt[poolId][newUVote.getExpiry()] += newUVote.slope;
        }

        // Record new user vote
        userPoolCheckpoints[user][poolId].push(Checkpoint(newUVote, block.timestamp));
        userPoolVotes[user][poolId] = UserPoolInfo(newUWeight, newUVote);
    }

    /**
     * @dev This function is aimed to be used by broadcast function, which will broadcast every pool
     * at once. So it is implemented so that no SSTORE is executed to save gas for broadcasting.
     *
     * @dev the updating code seems reusable by two functions getCurrentPoolVotes and updatePoolVotes
     * But one of them should be view, and the other should update the checkpoint for poolVote
     * on every of its iteration. Therefore, reusing code here is not possible.
     */
    function getPoolVotesCurrentEpoch(uint256 poolId) public view returns (uint256) {
        require(allPools[poolId].active, "pool not active");
        uint256 timestamp = allPools[poolId].timestamp;
        VeBalance memory votes = poolVotes[poolId];
        while (timestamp + WEEK <= block.timestamp) {
            timestamp += WEEK;
            votes = votes.sub(poolSlopeChangesAt[poolId][timestamp], timestamp);
        }
        return votes.getValueAt(timestamp);
    }

    function updatePoolVotes(uint256 poolId) public {
        require(allPools[poolId].active, "pool not active");
        uint256 timestamp = allPools[poolId].timestamp;
        VeBalance memory votes = poolVotes[poolId];

        while (timestamp + WEEK <= block.timestamp) {
            timestamp += WEEK;
            votes = votes.sub(poolSlopeChangesAt[poolId][timestamp], timestamp);
            poolVotesAt[poolId][timestamp] = votes.getValueAt(timestamp);
        }
        poolVotes[poolId] = votes;
        allPools[poolId].timestamp = timestamp;
    }

    /**
     * @dev It is required to broadcast all pools at once
     * @dev Each epoch, it is allowed to broadcast only once, and expected to be done by governance
     */
    function broadcastVotingResults() external payable {
        uint256 epochTimestamp = _getCurrentEpochStart();
        require(!epochBroadcasted[epochTimestamp], "not allowed to rebroadcast");

        uint256 totalVotes = 0;
        uint256 numChain = sidechainContracts.length();
        uint256[][] memory pools = new uint256[][](numChain);
        uint256[][] memory votes = new uint256[][](numChain);

        for (uint256 i = 0; i < numChain; ++i) {
            (uint256 chainId, ) = sidechainContracts.at(i);
            pools[i] = chainPools[chainId];
            votes[i] = new uint256[](pools[i].length);
            for (uint256 j = 0; j < pools[i].length; ++j) {
                uint256 poolId = pools[i][j];
                votes[i][j] = (getPoolVotesCurrentEpoch(poolId) * allPools[poolId].weight) / 100;
                totalVotes += votes[i][j];
            }
        }

        for (uint256 i = 0; i < numChain; ++i) {
            address[] memory markets = new address[](pools[i].length);
            uint256[] memory pendleSpeeds = new uint256[](pools[i].length);
            for (uint256 j = 0; j < pools[i].length; ++j) {
                markets[j] = allPools[pools[i][j]].market;
                pendleSpeeds[j] = (votes[i][j] * pendlePerSec) / totalVotes;
            }

            (uint256 chainId, address gaugeController) = sidechainContracts.at(i);

            if (block.chainid == chainId) {
                IPGaugeControllerMainchain(gaugeController).updateVotingResults(
                    epochTimestamp,
                    markets,
                    pendleSpeeds
                );
            } else {
                _sendMessage(
                    gaugeController,
                    chainId,
                    abi.encode(epochTimestamp, markets, pendleSpeeds)
                );
            }
        }
        epochBroadcasted[epochTimestamp] = true;
    }

    function setPendlePerSec(uint256 newPendlePerSec) external onlyGovernance {
        pendlePerSec = newPendlePerSec;
    }

    function _getCurrentEpochStart() internal view returns (uint256) {
        return (block.timestamp / WEEK) * WEEK;
    }

    function _getUserBalanceByWeight(address user, uint256 weight)
        internal
        view
        returns (VeBalance memory res)
    {
        (uint256 amount, uint256 expiry) = vePendle.positionData(user);
        require(expiry > block.timestamp, "user position expired");
        amount = (amount * weight) / MAX_WEIGHT / MAX_LOCK_TIME;
        res.slope = amount;
        res.bias = amount * expiry;
    }
}
