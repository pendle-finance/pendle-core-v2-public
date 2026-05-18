// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {PendleBridgedPrincipalToken} from "./PendleBridgedPrincipalToken.sol";
import {
    MessagingParams,
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Contract deployer must be IPBridgePTFactory for additional information.
///         This is for deterministic deployment.
contract PendleBridgedPrincipalTokenAlt is PendleBridgedPrincipalToken {
    using SafeERC20 for IERC20;

    error MsgValueNotZero(uint256 msgValue);
    error NativeTokenUnavailable();

    address public immutable nativeToken;

    constructor(address _lzEndpoint, uint256 _expiry, uint8 _decimals)
        PendleBridgedPrincipalToken(_lzEndpoint, _expiry, _decimals)
    {
        nativeToken = endpoint.nativeToken();
    }

    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal override returns (MessagingReceipt memory receipt) {
        // In Alt implementation, msg.value should always be 0 since we use ERC20 tokens for fees
        if (msg.value > 0) revert MsgValueNotZero(msg.value);

        // Push corresponding fees to the endpoint, any excess is sent back to the _refundAddress from the endpoint.
        _payNative(_fee.nativeFee);
        if (_fee.lzTokenFee > 0) _payLzToken(_fee.lzTokenFee);

        return endpoint.send(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _fee.lzTokenFee > 0), _refundAddress
        );
    }

    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (nativeToken == address(0)) revert NativeTokenUnavailable();

        // Pay Native token fee by sending tokens to the endpoint.
        IERC20(nativeToken).safeTransferFrom(msg.sender, address(endpoint), _nativeFee);

        return _nativeFee;
    }
}
