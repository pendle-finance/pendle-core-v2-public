// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../base/PendleCrossChainOracleBaseApp_Init.sol";
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

    mapping(uint32 srcEid => mapping(bytes32 source => ExchangeRateData)) private feedData;

    address public allowedSender;

    modifier onlyOwnerOrAllowedSender() {
        require(msg.sender == owner() || msg.sender == allowedSender, "Not authorized");
        _;
    }

    constructor(address _endpoint) PendleCrossChainOracleBaseApp_Init(_endpoint) {
        _disableInitializers();
    }

    function initialize(address _owner, address _delegate, address _allowedSender) external initializer {
        __PendleCrossChainOracleBaseApp_initialize(_owner, _delegate);
        _setAllowedSender(_allowedSender);
    }

    /// @inheritdoc IPExchangeRateOracleApp
    function quoteSendExchangeRateBatch(
        SendExchangeRateParam[] calldata sendParams,
        bool[] calldata payInLzTokens
    ) external view returns (MessagingFee[] memory fees) {
        if (sendParams.length != payInLzTokens.length) revert Errors.ArrayLengthMismatch();

        uint256 length = sendParams.length;
        fees = new MessagingFee[](length);

        for (uint256 i = 0; i < length; ++i) {
            fees[i] = _quoteSendExchangeRate(sendParams[i], payInLzTokens[i]);
        }
    }

    /// @inheritdoc IPExchangeRateOracleApp
    function quoteSendExchangeRate(
        SendExchangeRateParam calldata sendParam,
        bool payInLzToken
    ) external view returns (MessagingFee memory fee) {
        return _quoteSendExchangeRate(sendParam, payInLzToken);
    }

    /// @inheritdoc IPExchangeRateOracleApp
    function sendExchangeRateBatch(
        SendExchangeRateParam[] calldata sendParams,
        MessagingFee[] calldata fees
    ) external payable onlyOwnerOrAllowedSender returns (MessagingReceipt[] memory receipts) {
        if (sendParams.length != fees.length) revert Errors.ArrayLengthMismatch();
        _validateNativeFees(fees);

        uint256 length = sendParams.length;
        receipts = new MessagingReceipt[](length);

        for (uint256 i = 0; i < length; ++i) {
            receipts[i] = _sendExchangeRate(sendParams[i], fees[i]);
        }
    }

    /// @inheritdoc IPExchangeRateOracleApp
    function sendExchangeRate(
        SendExchangeRateParam calldata sendParam,
        MessagingFee calldata fee
    ) external payable onlyOwnerOrAllowedSender returns (MessagingReceipt memory receipt) {
        _validateNativeFee(fee);
        return _sendExchangeRate(sendParam, fee);
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

    function _quoteSendExchangeRate(
        SendExchangeRateParam calldata sendParam,
        bool payInLzToken
    ) internal view returns (MessagingFee memory fee) {
        _validateDstEid(sendParam.dstEid);
        uint256 exchangeRate = _getExchangeRateFromSource(sendParam.exchangeRateSource);
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(sendParam, exchangeRate);

        fee = _quote(sendParam.dstEid, message, options, payInLzToken);
    }

    function _sendExchangeRate(
        SendExchangeRateParam calldata sendParam,
        MessagingFee calldata fee
    ) internal returns (MessagingReceipt memory receipt) {
        _validateDstEid(sendParam.dstEid);
        uint256 exchangeRate = _getExchangeRateFromSource(sendParam.exchangeRateSource);
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(sendParam, exchangeRate);

        receipt = _lzSend(sendParam.dstEid, message, options, fee, msg.sender);

        emit ExchangeRateSent(receipt.guid, sendParam.dstEid, sendParam.exchangeRateSource, exchangeRate);
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

    function _validateDstEid(uint32 dstEid) internal view {
        if (dstEid == eid) revert Errors.InvalidDestinationEid();
    }

    /**
     * @dev Override of base _payNative function.
     * The original implementation enforced msg.value == _nativeFee, which is incompatible with
     * batching multiple messages. Fee checks are performed by _validateNativeFees / _validateNativeFee,
     * so this implementation simply returns the provided native fee.
     */
    function _payNative(uint256 _nativeFee) internal pure override returns (uint256 nativeFee) {
        return _nativeFee;
    }

    function _validateNativeFees(MessagingFee[] calldata fees) internal {
        uint256 totalFee = 0;
        for (uint256 i = 0; i < fees.length; ++i) {
            totalFee += fees[i].nativeFee;
        }

        if (totalFee != msg.value) revert Errors.NotEnoughNativeFee(msg.value, totalFee);
    }

    function _validateNativeFee(MessagingFee calldata fee) internal {
        if (fee.nativeFee != msg.value) revert Errors.NotEnoughNativeFee(msg.value, fee.nativeFee);
    }

    // ====== Admin functions ======

    function setAllowedSender(address _allowedSender) external onlyOwner {
        _setAllowedSender(_allowedSender);
    }

    function _setAllowedSender(address _allowedSender) internal {
        allowedSender = _allowedSender;
        emit AllowedSenderSet(_allowedSender);
    }
}
