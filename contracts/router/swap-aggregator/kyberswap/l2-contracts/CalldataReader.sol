// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IExecutorHelperL2Struct as L2Struct} from "../interfaces/IExecutorHelperL2Struct.sol";
import {IKyberDSLO} from "../interfaces/pools/IKyberDSLO.sol";
import {IKyberLO} from "../interfaces/pools/IKyberLO.sol";

library CalldataReader {
    /// @notice read the bytes value of data from a starting position and length
    /// @param data bytes array of data
    /// @param startByte starting position to read
    /// @param length length from starting position
    /// @return retVal value of the bytes
    /// @return (the next position to read from)
    function _calldataVal(
        bytes memory data,
        uint256 startByte,
        uint256 length
    ) internal pure returns (bytes memory retVal, uint256) {
        require(length + startByte <= data.length, "calldataVal trying to read beyond data size");
        uint256 loops = (length + 31) / 32;
        assembly {
            let m := mload(0x40)
            mstore(m, length)
            for {
                let i := 0
            } lt(i, loops) {
                i := add(1, i)
            } {
                mstore(add(m, mul(32, add(1, i))), mload(add(data, add(mul(32, add(1, i)), startByte))))
            }
            mstore(0x40, add(m, add(32, length)))
            retVal := m
        }
        return (retVal, length + startByte);
    }

    function _readRFQTQuote(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (L2Struct.RFQTQuote memory rfqQuote, uint256, uint256 ebtaStartByte) {
        (rfqQuote.pool, startByte) = _readAddress(data, startByte);
        (rfqQuote.externalAccount, startByte) = _readAddress(data, startByte);
        (rfqQuote.trader, startByte) = _readAddress(data, startByte);
        (rfqQuote.effectiveTrader, startByte) = _readAddress(data, startByte);
        // (rfqQuote.baseToken, startByte) = _readAddress(data, startByte);
        (rfqQuote.quoteToken, startByte) = _readAddress(data, startByte);
        ebtaStartByte = startByte;
        (rfqQuote.effectiveBaseTokenAmount, startByte) = _readUint128AsUint256(data, startByte);
        (rfqQuote.baseTokenAmount, startByte) = _readUint128AsUint256(data, startByte);
        (rfqQuote.quoteTokenAmount, startByte) = _readUint128AsUint256(data, startByte);
        (rfqQuote.quoteExpiry, startByte) = _readUint128AsUint256(data, startByte);
        (rfqQuote.nonce, startByte) = _readUint128AsUint256(data, startByte);
        (rfqQuote.txid, startByte) = _readBytes32(data, startByte);
        (rfqQuote.signature, startByte) = _readBytes(data, startByte);
        return (rfqQuote, startByte, ebtaStartByte);
    }

    function _readOrderRFQ(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (L2Struct.OrderRFQ memory orderRfq, uint256) {
        (orderRfq.info, startByte) = _readUint256(data, startByte);

        (orderRfq.makerAsset, startByte) = _readAddress(data, startByte);

        (orderRfq.takerAsset, startByte) = _readAddress(data, startByte);

        (orderRfq.maker, startByte) = _readAddress(data, startByte);

        (orderRfq.allowedSender, startByte) = _readAddress(data, startByte);

        (orderRfq.makingAmount, startByte) = _readUint128AsUint256(data, startByte);

        (orderRfq.takingAmount, startByte) = _readUint128AsUint256(data, startByte);

        return (orderRfq, startByte);
    }

    function _readDSLOFillBatchOrdersParams(
        bytes memory data,
        uint256 startByte
    )
        internal
        pure
        returns (
            IKyberDSLO.FillBatchOrdersParams memory params,
            uint256,
            uint256 takingAmountStartByte,
            uint256 thresholdStartByte
        )
    {
        (params.orders, startByte) = _readDSLOOrderArray(data, startByte);

        (params.signatures, startByte) = _readDSLOSignatureArray(data, startByte);

        (params.opExpireTimes, startByte) = _readUint32Array(data, startByte);

        // read taking amount and start byte to scale
        takingAmountStartByte = startByte;
        (params.takingAmount, startByte) = _readUint128AsUint256(data, startByte);

        // read threshold amount and start byte to update if scale dơn
        thresholdStartByte = startByte;
        (params.thresholdAmount, startByte) = _readUint128AsUint256(data, startByte);

        (params.target, startByte) = _readAddress(data, startByte);
        return (params, startByte, takingAmountStartByte, thresholdStartByte);
    }

    function _readLOFillBatchOrdersParams(
        bytes memory data,
        uint256 startByte
    )
        internal
        pure
        returns (
            IKyberLO.FillBatchOrdersParams memory params,
            uint256,
            uint256 takingAmountStartByte,
            uint256 thresholdStartByte
        )
    {
        (params.orders, startByte) = _readLOOrderArray(data, startByte);

        (params.signatures, startByte) = _readLOSignatureArray(data, startByte);

        takingAmountStartByte = startByte;
        (params.takingAmount, startByte) = _readUint128AsUint256(data, startByte);

        thresholdStartByte = startByte;
        (params.thresholdAmount, startByte) = _readUint128AsUint256(data, startByte);

        (params.target, startByte) = _readAddress(data, startByte);
        return (params, startByte, takingAmountStartByte, thresholdStartByte);
    }

    function _readLOSignatureArray(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (bytes[] memory signatures, uint256) {
        bytes memory ret;

        (ret, startByte) = _calldataVal(data, startByte, 1);
        uint256 length = uint256(uint8(bytes1(ret)));

        signatures = new bytes[](length);
        for (uint8 i = 0; i < length; ++i) {
            (signatures[i], startByte) = _readBytes(data, startByte);
        }
        return (signatures, startByte);
    }

    function _readDSLOSignatureArray(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (IKyberDSLO.Signature[] memory signatures, uint256) {
        bytes memory ret;

        (ret, startByte) = _calldataVal(data, startByte, 1);
        uint256 length = uint256(uint8(bytes1(ret)));

        signatures = new IKyberDSLO.Signature[](length);
        for (uint8 i = 0; i < length; ++i) {
            (signatures[i], startByte) = _readDSLOSignature(data, startByte);
        }
        return (signatures, startByte);
    }

    function _readDSLOSignature(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (IKyberDSLO.Signature memory signature, uint256) {
        (signature.orderSignature, startByte) = _readBytes(data, startByte);
        (signature.opSignature, startByte) = _readBytes(data, startByte);
        return (signature, startByte);
    }

    function _readLOOrderArray(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (IKyberLO.Order[] memory orders, uint256) {
        bytes memory ret;

        (ret, startByte) = _calldataVal(data, startByte, 1);
        uint256 length = uint256(uint8(bytes1(ret)));

        orders = new IKyberLO.Order[](length);
        for (uint8 i = 0; i < length; ++i) {
            (orders[i], startByte) = _readLOOrder(data, startByte);
        }
        return (orders, startByte);
    }

    function _readDSLOOrderArray(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (IKyberDSLO.Order[] memory orders, uint256) {
        bytes memory ret;

        (ret, startByte) = _calldataVal(data, startByte, 1);
        uint256 length = uint256(uint8(bytes1(ret)));

        orders = new IKyberDSLO.Order[](length);
        for (uint8 i = 0; i < length; ++i) {
            (orders[i], startByte) = _readDSLOOrder(data, startByte);
        }
        return (orders, startByte);
    }

    function _readDSLOOrder(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (IKyberDSLO.Order memory orders, uint256) {
        (orders.salt, startByte) = _readUint128AsUint256(data, startByte);
        (orders.makerAsset, startByte) = _readAddress(data, startByte);
        (orders.takerAsset, startByte) = _readAddress(data, startByte);
        (orders.maker, startByte) = _readAddress(data, startByte);
        (orders.receiver, startByte) = _readAddress(data, startByte);
        (orders.allowedSender, startByte) = _readAddress(data, startByte);
        (orders.makingAmount, startByte) = _readUint128AsUint256(data, startByte);
        (orders.takingAmount, startByte) = _readUint128AsUint256(data, startByte);
        (orders.feeConfig, startByte) = _readUint200(data, startByte);
        (orders.makerAssetData, startByte) = _readBytes(data, startByte);
        (orders.takerAssetData, startByte) = _readBytes(data, startByte);
        (orders.getMakerAmount, startByte) = _readBytes(data, startByte);
        (orders.getTakerAmount, startByte) = _readBytes(data, startByte);
        (orders.predicate, startByte) = _readBytes(data, startByte);
        (orders.interaction, startByte) = _readBytes(data, startByte);
        return (orders, startByte);
    }

    function _readLOOrder(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (IKyberLO.Order memory orders, uint256) {
        (orders.salt, startByte) = _readUint128AsUint256(data, startByte);
        (orders.makerAsset, startByte) = _readAddress(data, startByte);
        (orders.takerAsset, startByte) = _readAddress(data, startByte);
        (orders.maker, startByte) = _readAddress(data, startByte);
        (orders.receiver, startByte) = _readAddress(data, startByte);
        (orders.allowedSender, startByte) = _readAddress(data, startByte);
        (orders.makingAmount, startByte) = _readUint128AsUint256(data, startByte);
        (orders.takingAmount, startByte) = _readUint128AsUint256(data, startByte);
        (orders.feeRecipient, startByte) = _readAddress(data, startByte);
        (orders.makerTokenFeePercent, startByte) = _readUint32(data, startByte);
        (orders.makerAssetData, startByte) = _readBytes(data, startByte);
        (orders.takerAssetData, startByte) = _readBytes(data, startByte);
        (orders.getMakerAmount, startByte) = _readBytes(data, startByte);
        (orders.getTakerAmount, startByte) = _readBytes(data, startByte);
        (orders.predicate, startByte) = _readBytes(data, startByte);
        (orders.permit, startByte) = _readBytes(data, startByte);
        (orders.interaction, startByte) = _readBytes(data, startByte);
        return (orders, startByte);
    }

    function _readBool(bytes memory data, uint256 startByte) internal pure returns (bool, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 1);
        return (bytes1(ret) > 0, startByte);
    }

    function _readUint8(bytes memory data, uint256 startByte) internal pure returns (uint8, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 1);
        return (uint8(bytes1(ret)), startByte);
    }

    function _readUint24(bytes memory data, uint256 startByte) internal pure returns (uint24, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 3);
        return (uint24(bytes3(ret)), startByte);
    }

    function _readUint32(bytes memory data, uint256 startByte) internal pure returns (uint32, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 4);
        return (uint32(bytes4(ret)), startByte);
    }

    function _readUint128(bytes memory data, uint256 startByte) internal pure returns (uint128, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 16);
        return (uint128(bytes16(ret)), startByte);
    }

    function _readUint160(bytes memory data, uint256 startByte) internal pure returns (uint160, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 20);
        return (uint160(bytes20(ret)), startByte);
    }

    function _readUint200(bytes memory data, uint256 startByte) internal pure returns (uint200, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 25);
        return (uint200(bytes25(ret)), startByte);
    }

    function _readUint256(bytes memory data, uint256 startByte) internal pure returns (uint256, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 32);
        return (uint256(bytes32(ret)), startByte);
    }

    /// @dev only when sure that the value of uint256 never exceed uint128
    function _readUint128AsUint256(bytes memory data, uint256 startByte) internal pure returns (uint256, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 16);
        return (uint256(uint128(bytes16(ret))), startByte);
    }

    function _readAddress(bytes memory data, uint256 startByte) internal pure returns (address, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 20);
        return (address(bytes20(ret)), startByte);
    }

    function _readBytes1(bytes memory data, uint256 startByte) internal pure returns (bytes1, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 1);
        return (bytes1(ret), startByte);
    }

    function _readBytes4(bytes memory data, uint256 startByte) internal pure returns (bytes4, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 4);
        return (bytes4(ret), startByte);
    }

    function _readBytes32(bytes memory data, uint256 startByte) internal pure returns (bytes32, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 32);
        return (bytes32(ret), startByte);
    }

    /// @dev length of bytes is currently limited to uint32
    function _readBytes(bytes memory data, uint256 startByte) internal pure returns (bytes memory b, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 4);
        uint256 length = uint256(uint32(bytes4(ret)));
        (b, startByte) = _calldataVal(data, startByte, length);
        return (b, startByte);
    }

    /// @dev length of bytes array is currently limited to uint8
    function _readBytesArray(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (bytes[] memory bytesArray, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 1);
        uint256 length = uint256(uint8(bytes1(ret)));
        bytesArray = new bytes[](length);
        for (uint8 i; i != length; ++i) {
            (bytesArray[i], startByte) = _readBytes(data, startByte);
        }
        return (bytesArray, startByte);
    }

    /// @dev length of address array is currently limited to uint8 to save bytes
    function _readAddressArray(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (address[] memory addrs, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 1);
        uint256 length = uint256(uint8(bytes1(ret)));
        addrs = new address[](length);
        for (uint8 i; i != length; ++i) {
            (addrs[i], startByte) = _readAddress(data, startByte);
        }
        return (addrs, startByte);
    }

    /// @dev length of uint array is currently limited to uint8 to save bytes
    /// @dev same as _readUint128AsUint256, only use when sure that value never exceed uint128
    function _readUint128ArrayAsUint256Array(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (uint256[] memory, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 1);
        uint256 length = uint256(uint8(bytes1(ret)));
        uint256[] memory us = new uint256[](length);
        for (uint8 i; i != length; ++i) {
            (us[i], startByte) = _readUint128AsUint256(data, startByte);
        }
        return (us, startByte);
    }

    function _readUint32Array(
        bytes memory data,
        uint256 startByte
    ) internal pure returns (uint32[] memory arr, uint256) {
        bytes memory ret;
        (ret, startByte) = _calldataVal(data, startByte, 1);
        uint256 length = uint256(uint8(bytes1(ret)));
        arr = new uint32[](length);
        for (uint8 i = 0; i < length; ++i) {
            (arr[i], startByte) = _readUint32(data, startByte);
        }
        return (arr, startByte);
    }
}
