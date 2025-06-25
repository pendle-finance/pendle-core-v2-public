// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../core/libraries/BoringOwnableUpgradeableV2.sol";

contract EmptyUUPS is Initializable, UUPSUpgradeable, BoringOwnableUpgradeableV2 {
    constructor() initializer {}

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
