// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";

interface IPExchangeRateOracleApp {
    event ExchangeRateSent(
        bytes32 indexed guid,
        uint32 indexed dstEid,
        address indexed exchangeRateSource,
        uint256 exchangeRate
    );

    event ExchangeRateReceived(
        bytes32 indexed guid,
        uint32 indexed srcEid,
        bytes32 indexed exchangeRateSource,
        uint256 exchangeRate,
        uint256 updatedAt,
        bool rateAccepted
    );

    event AllowedSenderSet(address indexed sender);

    /**
     * @dev Parameters for the send operation
     * @param exchangeRateSource The address of the exchange rate source
     * @param dstEid Destination endpoint ID
     * @param extraOptions Additional LayerZero message options (e.g. gas limit configuration)
     */
    struct SendExchangeRateParam {
        address exchangeRateSource;
        uint32 dstEid;
        bytes extraOptions;
    }

    /**
     * @dev Exchange rate data with timestamp information
     * @param exchangeRate The exchange rate value
     * @param updatedAt Timestamp when the exchange rate was last updated
     */
    struct ExchangeRateData {
        uint256 exchangeRate;
        uint256 updatedAt;
    }

    /**
     * @dev Retrieves exchange rate from a data source on the specified chain
     * @param _srcEid Endpoint ID of the source chain
     * @param exchangeRateSource The exchange rate source identifier on the source chain
     */
    function getExchangeRate(
        uint32 _srcEid,
        bytes32 exchangeRateSource
    ) external view returns (ExchangeRateData memory exchangeRateData);

    /**
     * @dev Quote the fee required for sendExchangeRate execution
     * @param sendParam The parameters required for the sendExchangeRate execution operation
     * @param payInLzToken Flag indicating whether the caller is paying in the LZ token
     * @return fee The fee need to pay for sendExchangeRate operation request
     *      - nativeFee: the fee paid in native token
     *      - lzTokenFee: the fee paid in lzToken
     */
    function quoteSendExchangeRate(
        SendExchangeRateParam calldata sendParam,
        bool payInLzToken
    ) external view returns (MessagingFee memory fee);

    /**
     * @dev Quote the fees required for batch sendExchangeRate execution
     * @param sendParams Array of parameters for each sendExchangeRate operation.
     * @param payInLzTokens Array of flags indicating whether each call pays in LZ token.
     * @return fees Array of fees for each operation in the batch
     *      - nativeFee: the fee paid in native token for each operation
     *      - lzTokenFee: the fee paid in lzToken for each operation
     */
    function quoteSendExchangeRateBatch(
        SendExchangeRateParam[] calldata sendParams,
        bool[] calldata payInLzTokens
    ) external view returns (MessagingFee[] memory fees);

    /**
     * @dev Execute sending exchange rate to another chain
     * @param sendParam The parameters required for the operation
     * @param fee The calculated fee for the operation. This can be retrieved through quoteSendExchangeRate() for estimation
     *      - nativeFee: the fee paid in native token
     *      - lzTokenFee: the fee paid in lzToken
     * @return receipt The message receipt for the send operation, contains guid, nonce and the actual fee required
     */
    function sendExchangeRate(
        SendExchangeRateParam calldata sendParam,
        MessagingFee calldata fee
    ) external payable returns (MessagingReceipt memory receipt);

    /**
     * @dev Execute batch sending of exchange rates in a single transaction
     * @param sendParams Array of parameters for each operation.
     * @param fees Array of calculated fees for each operation. Retrieve via quoteSendExchangeRateBatch() for estimation
     *      - nativeFee: the fee paid in native token for each operation
     *      - lzTokenFee: the fee paid in lzToken for each operation
     * @return receipts Array of message receipts for each send operation, contains guid, nonce and the actual fee required
     * @notice msg.value must equal or exceed sum of all fees[i].nativeFee. Excess refunded to refundAddress
     * @notice If any operation fails, entire batch reverts
     */
    function sendExchangeRateBatch(
        SendExchangeRateParam[] calldata sendParams,
        MessagingFee[] calldata fees
    ) external payable returns (MessagingReceipt[] memory receipts);

    // ====== Admin functions ======

    function setAllowedSender(address _allowedSender) external;
}
