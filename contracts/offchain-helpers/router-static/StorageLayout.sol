// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

contract StorageLayout {
    address internal owner;
    address internal pendingOwner;

    struct FacetAndIndex {
        address addr;
        uint96 index;
    }

    struct SelectorsAndIndex {
        uint256 index;
        bytes4[] selectors;
    }

    mapping(bytes4 => FacetAndIndex) internal selectorToFacet;
    mapping(address => SelectorsAndIndex) internal facetToSelectors;
    address[] internal allFacets;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}
