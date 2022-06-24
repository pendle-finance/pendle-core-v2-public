// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

library ArrayLib {
    function padZeroRight(uint256[] memory input, uint256 length)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory output = new uint256[](length);
        uint256 inputLength = input.length;
        for (uint8 i = 0; i < length; ) {
            if (i < inputLength) output[i] = input[i];
            else output[i] = 0;
            unchecked {
                i++;
            }
        }
        return output;
    }

    function contains(address[] memory array, address element) internal pure returns (bool) {
        uint256 length = array.length;
        for (uint256 i = 0; i < length; ) {
            if (array[i] == element) return true;
            unchecked {
                i++;
            }
        }
        return false;
    }

    function append(address[] memory inp, address element)
        internal
        pure
        returns (address[] memory out)
    {
        uint256 length = inp.length;
        out = new address[](length + 1);
        for (uint256 i = 0; i < length; ) {
            out[i] = inp[i];
            unchecked {
                i++;
            }
        }
        out[length] = element;
    }

    function sub(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory res)
    {
        uint256 length = a.length;
        require(length == b.length, "length mismatch");
        res = new uint256[](length);

        for (uint256 i = 0; i < length; ) {
            res[i] = a[i] - b[i];
            unchecked {
                i++;
            }
        }
    }
}
