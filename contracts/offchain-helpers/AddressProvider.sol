pragma solidity ^0.8.17;

import "../interfaces/IAddressProvider.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";

contract AddressProvider is IAddressProvider, BoringOwnableUpgradeable {
    mapping(uint256 => address) public get;

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function set(uint256 id, address addr) external onlyOwner {
        get[id] = addr;
    }
}
