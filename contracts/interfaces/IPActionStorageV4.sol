// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPActionStorageV4 {
    struct SelectorsToFacet {
        address facet;
        bytes4[] selectors;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event SelectorToFacetSet(bytes4 indexed selector, address indexed facet);

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function transferOwnership(address newOwner, bool direct, bool renounce) external;

    function claimOwnership() external;

    function setSelectorToFacets(SelectorsToFacet[] calldata arr) external;

    function selectorToFacet(bytes4 selector) external view returns (address);
}
