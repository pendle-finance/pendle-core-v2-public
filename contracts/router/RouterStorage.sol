// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

abstract contract RouterStorage {
    struct CoreStorage {
        address owner;
        address pendingOwner;
        mapping(bytes4 => address) selectorToFacet;
    }

    // keccak256(abi.encode(uint256(keccak256("pendle.routerv4.Core")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CORE_STORAGE_LOCATION = 0xf168c5b0cb4aca9a68f931815c18a144c61ad01d6dd7ca15bd6741672a0ab800;

    function _getCoreStorage() internal pure returns (CoreStorage storage $) {
        assembly {
            $.slot := CORE_STORAGE_LOCATION
        }
    }
}
