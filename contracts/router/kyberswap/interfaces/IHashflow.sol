// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IHashflow {
    enum RFQType {
        TAKER,
        MAKER
    }

    struct Quote {
        RFQType rfqType;
        address pool;
        address eoa;
        address trader;
        address effectiveTrader;
        address baseToken;
        address quoteToken;
        uint256 effectiveBaseTokenAmount;
        uint256 maxBaseTokenAmount;
        uint256 maxQuoteTokenAmount;
        uint256 fees;
        uint256 quoteExpiry;
        uint256 nonce;
        bytes32 txid;
        bytes signedQuote;
    }

    function tradeSingleHop(Quote memory quote) external payable;
}
