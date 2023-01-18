// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../StorageLayout.sol";
import "../../../interfaces/IDiamondCut.sol";
import "../../../core/libraries/ArrayLib.sol";

// TODO: change all to custom errors
contract DiamondCutFacet is StorageLayout, IDiamondCut {
    using ArrayLib for bytes4[];

    function diamondCut(
        FacetCut[] calldata cuts,
        address initAddr,
        bytes calldata initData
    ) external override onlyOwner {
        for (uint256 i = 0; i < cuts.length; ) {
            FacetCut calldata facet = cuts[i];
            require(facet.facetAddress != address(0), "zero address");
            require(facet.functionSelectors.length != 0, "empty array");

            if (facet.action == FacetCutAction.Add) {
                _add(facet.facetAddress, facet.functionSelectors);
            } else if (facet.action == FacetCutAction.Replace) {
                _replace(facet.facetAddress, facet.functionSelectors);
            } else {
                _remove(facet.functionSelectors);
            }

            unchecked {
                i++;
            }
        }

        if (initAddr != address(0)) {
            (bool success, bytes memory returnData) = initAddr.delegatecall(initData);
            require(success, string(returnData));
        }

        emit DiamondCut(cuts, initAddr, initData);
    }

    /*///////////////////////////////////////////////////////////////
                            ADD
    //////////////////////////////////////////////////////////////*/

    function _add(address facet, bytes4[] calldata selectors) internal {
        if (facetToSelectorsAndIndex[facet].selectors.length == 0) {
            facetToSelectorsAndIndex[facet] = SelectorsAndIndex(new bytes4[](0), allFacets.length);
            allFacets.push(facet);
        }

        uint256 length = facetToSelectorsAndIndex[facet].selectors.length;

        for (uint256 i = 0; i < selectors.length; ) {
            bytes4 selector = selectors[i];
            require(selectorToFacetAndIndex[selector].facet == address(0), "already existed");

            selectorToFacetAndIndex[selector] = FacetAndIndex(facet, uint96(length + i));
            facetToSelectorsAndIndex[facet].selectors.push(selector);

            unchecked {
                i++;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            REPLACE
    //////////////////////////////////////////////////////////////*/

    function _replace(address newFacet, bytes4[] calldata selectors) internal {
        _remove(selectors);
        _add(newFacet, selectors);
    }

    /*///////////////////////////////////////////////////////////////
                            REMOVE
    //////////////////////////////////////////////////////////////*/

    function _remove(bytes4[] calldata selectors) internal {
        for (uint256 i = 0; i < selectors.length; ) {
            bytes4 selector = selectors[i];

            FacetAndIndex memory facetAndIndex = selectorToFacetAndIndex[selector];
            require(facetAndIndex.facet != address(0), "not existed");

            uint256 nLenArr = _removeSelector(facetAndIndex.facet, facetAndIndex.index);

            delete selectorToFacetAndIndex[selector];
            if (nLenArr == 0) _removeFacet(facetAndIndex.facet);

            unchecked {
                i++;
            }
        }
    }

    function _removeSelector(address facet, uint96 index) internal returns (uint256) {
        bytes4[] storage selectors = facetToSelectorsAndIndex[facet].selectors;

        uint256 last = selectors.length - 1;
        if (index != last) {
            bytes4 selector = selectors[last];
            selectors[index] = selector;
            selectorToFacetAndIndex[selector].index = index;
        }

        selectors.pop();

        return last;
    }

    function _removeFacet(address facet) internal returns (uint256) {
        uint256 index = facetToSelectorsAndIndex[facet].index;

        uint256 last = allFacets.length - 1;

        if (index != last) {
            address lastFacet = allFacets[last];
            allFacets[index] = lastFacet;
            facetToSelectorsAndIndex[lastFacet].index = uint96(index);
        }

        allFacets.pop();

        return last;
    }
}
