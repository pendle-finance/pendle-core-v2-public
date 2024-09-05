pragma solidity ^0.8.0;

library BytesHelper {
    function splitCalldata(bytes memory data) internal pure returns (bytes4 selector, bytes memory functionCalldata) {
        require(data.length >= 4, "Calldata too short");

        // Extract the selector
        assembly {
            selector := mload(add(data, 32))
        }
        // Extract the function calldata
        functionCalldata = new bytes(data.length - 4);
        for (uint256 i = 0; i < data.length - 4; i++) {
            functionCalldata[i] = data[i + 4];
        }
    }

    function writeBytes(
        bytes memory originalCalldata,
        uint256 index,
        bytes memory value
    ) internal pure returns (bytes memory) {
        require(index + value.length <= originalCalldata.length, "Offset out of bounds");

        // Update the value length bytes at the specified offset with the new value
        for (uint256 i; i < value.length; ++i) {
            originalCalldata[index + i] = value[i];
        }

        return originalCalldata;
    }

    function write16Bytes(bytes memory original, uint256 index, bytes16 value) internal pure returns (bytes memory) {
        assembly {
            let offset := add(original, add(index, 32))
            let val := mload(offset) // read 32 bytes [index : index + 32]
            val := and(val, not(0xffffffffffffffffffffffffffffffff00000000000000000000000000000000)) // clear [index : index + 16]
            val := or(val, value) // set 16 bytes to val above
            mstore(offset, val) // store to [index : index + 32]
        }
        return original;
    }

    function write16Bytes(bytes memory original, uint256 index, uint128 value) internal pure returns (bytes memory) {
        return write16Bytes(original, index, bytes16(value));
    }

    function write16Bytes(
        bytes memory original,
        uint256 index,
        uint256 value,
        string memory errorMsg
    ) internal pure returns (bytes memory) {
        require(value <= type(uint128).max, string(abi.encodePacked(errorMsg, "/Exceed compressed type range")));
        return write16Bytes(original, index, uint128(value));
    }

    /**
     * @dev Writes a 32-byte value into the specified index of a bytes array.
     * @param original The original bytes array.
     * @param index The index in the bytes array where the 32-byte value should be written.
     * @param value The 32-byte value to write.
     * @return The modified bytes array.
     */
    function write32Bytes(bytes memory original, uint256 index, bytes32 value) internal pure returns (bytes memory) {
        assembly {
            let offset := add(add(original, 32), index)
            mstore(offset, value) // Store the 32-byte value directly at the specified offset
        }
        return original;
    }

    /**
     * @dev Overloaded function to write a uint256 value as a 32-byte value.
     * @param original The original bytes array.
     * @param index The index in the bytes array where the 32-byte value should be written.
     * @param value The uint256 value to write.
     * @return The modified bytes array.
     */
    function write32Bytes(bytes memory original, uint256 index, uint256 value) internal pure returns (bytes memory) {
        return write32Bytes(original, index, bytes32(value));
    }

    function write32Bytes(
        bytes memory original,
        uint256 index,
        uint256 value,
        string memory errorMsg
    ) internal pure returns (bytes memory) {
        require(value <= type(uint128).max, string(abi.encodePacked(errorMsg, "/Exceed compressed type range")));
        return write32Bytes(original, index, value);
    }
}
