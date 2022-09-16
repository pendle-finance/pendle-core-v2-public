// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./PendleFeeDistributor.sol";
import "./EpochResultManager.sol";
import "../../../libraries/helpers/BaseSplitCodeFactory.sol";
import "../../../interfaces/IBoringOwnableUpgradeable.sol";
import "../../../interfaces/IPFeeDistributorFactory.sol";

contract PendleFeeDistributorFactory is BoringOwnableUpgradeable, EpochResultManager {
    using Math for uint256;

    struct PoolInfo {
        address distributor;
        uint64 startTime;
    }

    address public immutable feeDistributorCreationCodeContractA;
    uint256 public immutable feeDistributorCreationCodeSizeA;
    address public immutable feeDistributorCreationCodeContractB;
    uint256 public immutable feeDistributorCreationCodeSizeB;

    address public immutable rewardToken;
    uint256 public lastFinishedEpoch;
    mapping(address => PoolInfo) public poolInfos;

    constructor(
        address _rewardToken,
        address _votingController,
        address _vePendle,
        address _feeDistributorCreationCodeContractA,
        uint256 _feeDistributorCreationCodeSizeA,
        address _feeDistributorCreationCodeContractB,
        uint256 _feeDistributorCreationCodeSizeB
    ) EpochResultManager(_votingController, _vePendle) initializer {
        __BoringOwnable_init();
        rewardToken = _rewardToken;
        feeDistributorCreationCodeContractA = _feeDistributorCreationCodeContractA;
        feeDistributorCreationCodeSizeA = _feeDistributorCreationCodeSizeA;
        feeDistributorCreationCodeContractB = _feeDistributorCreationCodeContractB;
        feeDistributorCreationCodeSizeB = _feeDistributorCreationCodeSizeB;
    }

    function createFeeDistributor(address pool, uint64 startTime)
        external
        onlyOwner
        returns (address distributor)
    {
        require(poolInfos[pool].distributor == address(0), "distributor already created");

        distributor = BaseSplitCodeFactory._create2(
            0,
            bytes32(""),
            abi.encode(pool, rewardToken, uint256(startTime)),
            feeDistributorCreationCodeContractA,
            feeDistributorCreationCodeSizeA,
            feeDistributorCreationCodeContractB,
            feeDistributorCreationCodeSizeB
        );
        IBoringOwnableUpgradeable(distributor).transferOwnership(msg.sender, true, false);
        poolInfos[pool] = PoolInfo({ distributor: distributor, startTime: startTime });
    }

    function _getPoolStartTime(address pool) internal view virtual override returns (uint64) {
        return poolInfos[pool].startTime;
    }
}
