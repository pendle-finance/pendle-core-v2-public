// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {IPBridgedPrincipalToken} from "../../../interfaces/IPBridgedPrincipalToken.sol";
import {OFT, OFTCore, IOFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract PendleBridgedPrincipalToken is IPBridgedPrincipalToken, OFT {
    uint256 public immutable expiry;
    uint8 internal immutable LOCAL_DECIMALS;
    uint8 internal immutable SHARED_DECIMALS;

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate,
        uint256 _expiry,
        uint8 _localDecimals,
        uint8 _sharedDecimals,
        address initialOwner
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) {
        expiry = _expiry;
        _transferOwnership(initialOwner);

        LOCAL_DECIMALS = _localDecimals;
        SHARED_DECIMALS = _sharedDecimals;

        // override decimalConversionRate set in OFTCore constructor
        decimalConversionRate = 10 ** (LOCAL_DECIMALS - SHARED_DECIMALS);
    }

    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return LOCAL_DECIMALS;
    }

    function sharedDecimals() public view override(OFTCore, IOFT) returns (uint8) {
        return SHARED_DECIMALS;
    }
}
