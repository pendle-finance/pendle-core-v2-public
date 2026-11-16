// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Errors} from "../../../core/libraries/Errors.sol";

library ExchangeRateMsgCodec {
    uint16 public constant SEND_EXCHANGE_RATE = 1;

    function encodeExchangeRateMessage(address exchangeRateSource, uint256 exchangeRate, uint256 updatedAt)
        internal
        pure
        returns (uint16 msgType, bytes memory message)
    {
        msgType = SEND_EXCHANGE_RATE;
        message = abi.encode(msgType, exchangeRateSource, exchangeRate, updatedAt);
    }

    function decodeMessage(bytes calldata message)
        internal
        pure
        returns (bytes32 exchangeRateSource, uint256 exchangeRate, uint256 updatedAt)
    {
        uint16 msgType;
        (msgType, exchangeRateSource, exchangeRate, updatedAt) =
            abi.decode(message, (uint16, bytes32, uint256, uint256));
        if (msgType != SEND_EXCHANGE_RATE) revert Errors.InvalidMsgType();
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function bytes32ToAddress(bytes32 _b) internal pure returns (address) {
        return address(uint160(uint256(_b)));
    }
}
