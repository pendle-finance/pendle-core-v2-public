// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleFeeDistributor.sol";
import "./EpochResultManager.sol";
import "../../../interfaces/IBoringOwnableUpgradeable.sol";
import "../../../interfaces/IPFeeDistributorFactory.sol";

contract PendleFeeDistributorFactory is BoringOwnableUpgradeable, EpochResultManager {
    using Math for uint256;

    struct PoolInfo {
        address distributor;
        uint64 startTime;
    }

    address public immutable rewardToken;
    uint256 public lastFinishedEpoch;

    mapping(address => PoolInfo) public poolInfos;

    constructor(
        address _rewardToken,
        address _votingController,
        address _vePendle
    ) EpochResultManager(_votingController, _vePendle) {
        rewardToken = _rewardToken;
    }

    function createFeeDistributor(address pool, uint64 startTime)
        external
        onlyOwner
        returns (address distributor)
    {
        require(poolInfos[pool].distributor == address(0), "distributor already created");

        // to use create2 later
        distributor = address(new PendleFeeDistributor(pool, rewardToken, startTime));
        IBoringOwnableUpgradeable(distributor).transferOwnership(msg.sender, true, false);

        poolInfos[pool] = PoolInfo({ distributor: distributor, startTime: startTime });
    }

    function _getPoolStartTime(address pool) internal view virtual override returns (uint64) {
        return poolInfos[pool].startTime;
    }
}
