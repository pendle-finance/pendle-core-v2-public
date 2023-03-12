pragma solidity ^0.8.17;

interface IPMiniDiamond {
    struct SelectorsToFacet {
        address facet;
        bytes4[] selectors;
    }

    function setFacetForSelectors(SelectorsToFacet[] calldata arr) external;

    function facetAddress(bytes4 selector) external view returns (address);
}
