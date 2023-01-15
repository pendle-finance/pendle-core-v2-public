// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../StorageLayout.sol";
import "../../../interfaces/IDiamondLoupe.sol";

contract DiamondLoupeFacet is StorageLayout, IDiamondLoupe {
    function facets() external view override returns (Facet[] memory facets_) {
        uint256 numFacets = allFacets.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i = 0; i < numFacets; ) {
            address addr = allFacets[i];
            facets_[i] = Facet(addr, facetToSelectors[addr].selectors);
            unchecked {
                i++;
            }
        }
    }

    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        return facetToSelectors[_facet].selectors;
    }

    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        return allFacets;
    }

    function facetAddress(bytes4 _functionSelector)
        external
        view
        override
        returns (address facetAddress_)
    {
        return selectorToFacet[_functionSelector].addr;
    }
}
