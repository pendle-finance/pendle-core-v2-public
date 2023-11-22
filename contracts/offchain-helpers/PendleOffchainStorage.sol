// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IPOffchainStorage.sol";

contract PendleOffchainStorage is IPOffchainStorage, UUPSUpgradeable, AccessControlUpgradeable {
    bytes32 public constant MAINTAINER = keccak256("MAINTAINER");

    constructor() initializer {}

    modifier onlyMaintainer() {
        require(isMaintainer(msg.sender), "not maintainer");
        _;
    }

    function isMaintainer(address addr) public view returns (bool) {
        return (hasRole(DEFAULT_ADMIN_ROLE, addr) || hasRole(MAINTAINER, addr));
    }

    /*///////////////////////////////////////////////////////////////
                                CORE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => bytes) internal _storage;

    function setStorageUint256(bytes32 key, uint256 value) external onlyMaintainer {
        _setStorage(key, abi.encode(value));
    }

    function setStorage(bytes32 key, bytes memory value) external onlyMaintainer {
        _setStorage(key, value);
    }

    function getUint256(bytes32 key) external view returns (uint256) {
        return abi.decode(_storage[key], (uint256));
    }

    function _setStorage(bytes32 key, bytes memory value) internal {
        _storage[key] = value;
        emit SetStorage(key, value);
    }

    // TODO: update more getSomething functions later when theres a need

    /*///////////////////////////////////////////////////////////////
                            UPGRADABLE RELATED
    //////////////////////////////////////////////////////////////*/
    function initialize() external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address) internal view override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "not admin");
    }

    uint256[49] private __gap;
}
