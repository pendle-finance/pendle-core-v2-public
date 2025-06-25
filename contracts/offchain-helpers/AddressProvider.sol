pragma solidity ^0.8.17;

import "../interfaces/IAddressProvider.sol";
import "../core/libraries/BoringOwnableUpgradeableV2.sol";

contract AddressProvider is IAddressProvider, BoringOwnableUpgradeableV2 {
    mapping(uint256 => address) public get;

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function set(uint256 id, address addr) external onlyOwner {
        get[id] = addr;
    }
}
