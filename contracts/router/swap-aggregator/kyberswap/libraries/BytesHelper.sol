pragma solidity ^0.8.0;

library BytesHelper {
    function update(
        bytes memory originalCalldata,
        uint256 newAmount,
        uint256 amountInOffset
    ) internal pure returns (bytes memory) {
        require(amountInOffset + 32 <= originalCalldata.length, "Offset out of bounds");

        // Update the 32 bytes at the specified offset with the new amount
        for (uint256 i; i < 32; ++i) {
            originalCalldata[amountInOffset + i] = bytes32(newAmount)[i];
        }

        return originalCalldata;
    }

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
}
