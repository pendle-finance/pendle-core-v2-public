// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../../../core/libraries/BoringOwnableUpgradeable.sol";
import "../../../core/libraries/Errors.sol";
import "../../../interfaces/IPFeeDistributorFactory.sol";

contract PendleFeeDistributorFactory is
    UUPSUpgradeable,
    BoringOwnableUpgradeable,
    IPFeeDistributorFactory
{
    address public implementation;
    address public immutable rewardToken;
    address public immutable vePendle;
    address public immutable votingController;

    struct FeeDistributorInfo {
        address distributor;
        uint64 startTime;
    }

    mapping(address => FeeDistributorInfo) public feeDistributors;

    constructor(
        address _votingController,
        address _vePendle,
        address _rewardToken
    ) initializer {
        votingController = _votingController;
        vePendle = _vePendle;
        rewardToken = _rewardToken;
    }

    function initialize(address implementation_) external initializer {
        __BoringOwnable_init();
        upgradeBeacon(implementation_);
    }

    /**
     * @param startTime this param should be the epoch timestamp before totalSupply/totalVote of the pool differ from 0
     */
    function createFeeDistributor(address pool, uint256 startTime)
        external
        onlyOwner
        returns (address distributor)
    {
        if (feeDistributors[pool].distributor != address(0))
            revert Errors.FDAlreadyExists(pool, feeDistributors[pool].distributor);

        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,address,address,uint256,address)",
            votingController,
            vePendle,
            pool,
            rewardToken,
            startTime,
            address(this)
        );

        distributor = address(new BeaconProxy(address(this), data));
        feeDistributors[pool] = FeeDistributorInfo({
            distributor: distributor,
            startTime: uint64(startTime)
        });

        return distributor;
    }

    function isAdmin(address addr) public view override returns (bool) {
        return addr == owner;
    }

    // ----------------- upgrade-related -----------------
    function upgradeBeacon(address newImplementation) public onlyOwner {
        require(
            AddressUpgradeable.isContract(newImplementation),
            "UpgradeableBeacon: implementation is not a contract"
        );
        implementation = newImplementation;
        emit UpgradedBeacon(newImplementation);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
