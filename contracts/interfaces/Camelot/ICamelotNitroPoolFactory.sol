// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ICamelotNitroPoolFactory {
    event CreateNitroPool(address nitroAddress);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PublishNitroPool(address nitroAddress);
    event SetDefaultFee(uint256 fee);
    event SetEmergencyRecoveryAddress(address emergencyRecoveryAddress);
    event SetExemptedAddress(address exemptedAddress, bool isExempted);
    event SetFeeAddress(address feeAddress);
    event SetNitroPoolOwner(address previousOwner, address newOwner);

    struct Settings {
        uint256 startTime;
        uint256 endTime;
        uint256 harvestStartTime;
        uint256 depositEndTime;
        uint256 lockDurationReq;
        uint256 lockEndReq;
        uint256 depositAmountReq;
        bool whitelist;
        string description;
    }

    function MAX_DEFAULT_FEE() external view returns (uint256);

    function createNitroPool(
        address nftPoolAddress,
        address rewardsToken1,
        address rewardsToken2,
        Settings memory settings
    ) external returns (address nitroPool);

    function defaultFee() external view returns (uint256);

    function emergencyRecoveryAddress() external view returns (address);

    function exemptedAddressesLength() external view returns (uint256);

    function feeAddress() external view returns (address);

    function getExemptedAddress(uint256 index) external view returns (address);

    function getNftPoolPublishedNitroPool(address nftPoolAddress, uint256 index) external view returns (address);

    function getNitroPool(uint256 index) external view returns (address);

    function getNitroPoolFee(address nitroPoolAddress, address ownerAddress) external view returns (uint256);

    function getOwnerNitroPool(address userAddress, uint256 index) external view returns (address);

    function getPublishedNitroPool(uint256 index) external view returns (address);

    function grailToken() external view returns (address);

    function isExemptedAddress(address checkedAddress) external view returns (bool);

    function nftPoolPublishedNitroPoolsLength(address nftPoolAddress) external view returns (uint256);

    function nitroPoolsLength() external view returns (uint256);

    function owner() external view returns (address);

    function ownerNitroPoolsLength(address userAddress) external view returns (uint256);

    function publishNitroPool(address nftAddress) external;

    function publishedNitroPoolsLength() external view returns (uint256);

    function renounceOwnership() external;

    function setDefaultFee(uint256 newFee) external;

    function setEmergencyRecoveryAddress(address emergencyRecoveryAddress_) external;

    function setExemptedAddress(address exemptedAddress, bool isExempted) external;

    function setFeeAddress(address feeAddress_) external;

    function setNitroPoolOwner(address previousOwner, address newOwner) external;

    function transferOwnership(address newOwner) external;

    function xGrailToken() external view returns (address);
}
