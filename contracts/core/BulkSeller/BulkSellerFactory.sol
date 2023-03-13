// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../libraries/BoringOwnableUpgradeable.sol";

import "../../interfaces/IStandardizedYield.sol";
import "../../interfaces/IPBulkSellerFactory.sol";
import "../libraries/Errors.sol";

contract BulkSellerFactory is
    IBeacon,
    IPBulkSellerFactory,
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MAINTAINER = keccak256("MAINTAINER");

    address public implementation;

    mapping(address => mapping(address => address)) internal syToBulkSeller;

    modifier onlyMaintainer() {
        if (!isMaintainer(msg.sender)) revert Errors.BulkNotMaintainer();
        _;
    }

    constructor() initializer {}

    function initialize(address implementation_) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        upgradeBeacon(implementation_);
    }

    function createBulkSeller(
        address token,
        address SY
    ) external onlyMaintainer returns (address bulk) {
        IStandardizedYield _SY = IStandardizedYield(SY);
        if (syToBulkSeller[token][SY] != address(0))
            revert Errors.BulkSellerAlreadyExisted(token, SY, syToBulkSeller[token][SY]);
        if (_SY.isValidTokenIn(token) == false || _SY.isValidTokenOut(token) == false)
            revert Errors.BulkSellerInvalidToken(token, SY);

        bytes memory data = abi.encodeWithSignature(
            "initialize(address,address,address)",
            token,
            SY,
            address(this)
        );

        bulk = address(new BeaconProxy(address(this), data));

        syToBulkSeller[token][SY] = bulk;

        emit BulkSellerCreated(token, SY, bulk);

        return bulk;
    }

    function get(address token, address SY) external view override returns (address) {
        return syToBulkSeller[token][SY];
    }

    function isMaintainer(address addr) public view override returns (bool) {
        return (hasRole(DEFAULT_ADMIN_ROLE, addr) || hasRole(MAINTAINER, addr));
    }

    // ----------------- upgrade-related -----------------
    function upgradeBeacon(address newImplementation) public onlyMaintainer {
        require(
            AddressUpgradeable.isContract(newImplementation),
            "UpgradeableBeacon: implementation is not a contract"
        );
        implementation = newImplementation;
        emit UpgradedBeacon(newImplementation);
    }

    function _authorizeUpgrade(address) internal override onlyMaintainer {}
}
