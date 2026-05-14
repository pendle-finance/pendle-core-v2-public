// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IPBridgedPrincipalToken} from "../../../interfaces/IPBridgedPrincipalToken.sol";
import {
    IOFT,
    OFTCoreUpgradeable,
    OFTUpgradeable
} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

/// @notice Contract deployer must be IPBridgePTFactory for additional information.
///         This is for deterministic deployment.
contract PendleBridgedPrincipalToken is IPBridgedPrincipalToken, OFTUpgradeable {
    uint256 public immutable expiry;
    uint8 internal immutable LOCAL_DECIMALS;

    constructor(address _lzEndpoint, uint256 _expiry, uint8 _decimals) OFTUpgradeable(_lzEndpoint) {
        expiry = _expiry;

        LOCAL_DECIMALS = _decimals;

        uint8 shared = sharedDecimals();
        require(LOCAL_DECIMALS >= shared, "InvalidLocalDecimals");

        // override decimalConversionRate set in OFTCore constructor
        decimalConversionRate = 10 ** (LOCAL_DECIMALS - sharedDecimals());

        _disableInitializers();
    }

    function initialize(string memory _name, string memory _symbol, address ownerDelegate) external initializer {
        __OFT_init(_name, _symbol, ownerDelegate);
        _transferOwnership(ownerDelegate);
    }

    /// @dev This functions is used to passed in the decimals to OFTCoreUpgradeable's constructor.
    /// Since `LOCAL_DECIMALS` was not initialized at that point, we return 18 to avoid the `InvalidLocalDecimals`
    /// revert.
    ///
    /// See
    /// https://github.com/LayerZero-Labs/devtools/blob/128b697838f4b0fd53ae748093fd66cc409ae5c4/packages/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol#L72
    function decimals() public view override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (uint8 res) {
        res = LOCAL_DECIMALS;
        if (res == 0) res = 18;
    }
}
