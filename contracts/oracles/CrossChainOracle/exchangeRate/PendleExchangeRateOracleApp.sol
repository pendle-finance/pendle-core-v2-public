// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../base/PendleCrossChainOracleBaseApp_Init.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import "../../../interfaces/IPExchangeRateOracleApp.sol";
import {IStandardizedYield} from "../../../interfaces/IStandardizedYield.sol";
import {ExchangeRateMsgCodec} from "../libraries/ExchangeRateMsgCodec.sol";
import {Errors} from "../../../core/libraries/Errors.sol";

/**
 * @title PendleExchangeRateOracleApp
 * @notice Cross-chain oracle for Pendle exchange rates using LayerZero
 */
contract PendleExchangeRateOracleApp is PendleCrossChainOracleBaseApp_Init, IPExchangeRateOracleApp {
    using ExchangeRateMsgCodec for bytes;
    using ExchangeRateMsgCodec for bytes32;

    uint32 public immutable eid;
    mapping(uint32 srcEid => mapping(bytes32 source => ExchangeRateData)) private feedData;

    modifier validateDstEid(uint32 dstEid) {
        if (dstEid == eid) revert Errors.InvalidDestinationEid();
        _;
    }

    constructor(
        address _endpoint,
        address payable _refundAddress
    ) PendleCrossChainOracleBaseApp_Init(_endpoint, _refundAddress) {
        _disableInitializers();
        eid = ILayerZeroEndpointV2(_endpoint).eid();
    }

    /// @inheritdoc IPExchangeRateOracleApp
    function quoteSendExchangeRate(
        SendExchangeRateParam calldata sendParam,
        bool payInLzToken
    ) external view returns (MessagingFee memory fee) {
        uint256 exchangeRate = _getExchangeRateFromSource(sendParam.exchangeRateSource);
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(sendParam, exchangeRate);

        fee = _quote(sendParam.dstEid, message, options, payInLzToken);
    }

    /// @inheritdoc IPExchangeRateOracleApp
    function sendExchangeRate(
        SendExchangeRateParam calldata sendParam,
        MessagingFee calldata fee
    ) external payable onlyOwner validateDstEid(sendParam.dstEid) returns (MessagingReceipt memory receipt) {
        uint256 exchangeRate = _getExchangeRateFromSource(sendParam.exchangeRateSource);
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(sendParam, exchangeRate);

        receipt = _lzSend(sendParam.dstEid, message, options, fee, refundAddress);

        emit ExchangeRateSent(receipt.guid, sendParam.dstEid, sendParam.exchangeRateSource, exchangeRate);
    }

    /// @inheritdoc IPExchangeRateOracleApp
    function getExchangeRate(
        uint32 _srcEid,
        bytes32 exchangeRateSource
    ) external view returns (ExchangeRateData memory exchangeRateData) {
        if (_srcEid == eid) {
            uint256 exchangeRate = _getExchangeRateFromSource(exchangeRateSource.bytes32ToAddress());
            return ExchangeRateData(exchangeRate, block.timestamp);
        }

        exchangeRateData = feedData[_srcEid][exchangeRateSource];

        if (exchangeRateData.updatedAt == 0) revert Errors.FeedNotInitialized();
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (bytes32 exchangeRateSource, uint256 exchangeRate, uint256 updatedAt) = _message.decodeMessage();

        bool rateAccepted = _updateExchangeRate(_origin.srcEid, exchangeRateSource, exchangeRate, updatedAt);

        emit ExchangeRateReceived(_guid, _origin.srcEid, exchangeRateSource, exchangeRate, updatedAt, rateAccepted);
    }

    function _buildMsgAndOptions(
        SendExchangeRateParam calldata sendParam,
        uint256 exchangeRate
    ) internal view returns (bytes memory message, bytes memory options) {
        uint16 msgType;

        (msgType, message) = ExchangeRateMsgCodec.encodeExchangeRateMessage(
            sendParam.exchangeRateSource,
            exchangeRate,
            block.timestamp
        );

        options = combineOptions(sendParam.dstEid, msgType, sendParam.extraOptions);
    }

    function _getExchangeRateFromSource(address exchangeRateSource) internal view returns (uint256) {
        try IStandardizedYield(exchangeRateSource).exchangeRate() returns (uint256 exchangeRate) {
            return exchangeRate;
        } catch (bytes memory revertData) {
            uint256 length = revertData.length;
            if (length != 0) {
                assembly {
                    revert(add(revertData, 32), length)
                }
            }
            revert Errors.ExchangeRateCallFailed();
        }
    }

    function _updateExchangeRate(
        uint32 _srcEid,
        bytes32 exchangeRateSource,
        uint256 exchangeRate,
        uint256 updatedAt
    ) internal returns (bool rateAccepted) {
        ExchangeRateData storage currentFeedData = feedData[_srcEid][exchangeRateSource];

        if (updatedAt > currentFeedData.updatedAt) {
            rateAccepted = true;
            currentFeedData.exchangeRate = exchangeRate;
            currentFeedData.updatedAt = updatedAt;
        }
    }
}
