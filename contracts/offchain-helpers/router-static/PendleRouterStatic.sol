// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../../interfaces/IDiamondLoupe.sol";
import "../../interfaces/IDiamondCut.sol";
import "./core-logic/StaticAddRemoveLiqFacet.sol";
import "./core-logic/StaticMarketInfoFacet.sol";
import "./core-logic/StaticMintRedeemFacet.sol";
import "./core-logic/StaticSwapFacet.sol";
import "./core-logic/StaticVePendleFacet.sol";
import "./aux-logic/DiamondCutFacet.sol";
import "./aux-logic/DiamondLoupeFacet.sol";
import "./aux-logic/BoringOwnableFacet.sol";
import "../../core/libraries/ArrayLib.sol";

// solhint-disable no-empty-blocks
contract PendleRouterStatic is Proxy, StorageLayout {
    constructor() {
        address diamondCutFacet = address(new DiamondCutFacet());
        address diamondLoupeFacet = address(new DiamondLoupeFacet());
        address boringOwnableFacet = address(new BoringOwnableFacet());

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);

        {
            // DiamondCutFacet
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = IDiamondCut.diamondCut.selector;
            cut[0] = IDiamondCut.FacetCut(
                diamondCutFacet,
                IDiamondCut.FacetCutAction.Add,
                selectors
            );
        }

        {
            // DiamondLoupeFacet
            bytes4[] memory selectors = new bytes4[](4);
            selectors[0] = IDiamondLoupe.facetAddress.selector;
            selectors[1] = IDiamondLoupe.facetAddresses.selector;
            selectors[2] = IDiamondLoupe.facetFunctionSelectors.selector;
            selectors[3] = IDiamondLoupe.facets.selector;
            cut[1] = IDiamondCut.FacetCut(
                diamondLoupeFacet,
                IDiamondCut.FacetCutAction.Add,
                selectors
            );
        }

        {
            // BoringOwnableFacet
            bytes4[] memory selectors = new bytes4[](2);
            selectors[0] = BoringOwnableFacet.transferOwnership.selector;
            selectors[1] = BoringOwnableFacet.claimOwnership.selector;
            cut[2] = IDiamondCut.FacetCut(
                boringOwnableFacet,
                IDiamondCut.FacetCutAction.Add,
                selectors
            );
        }

        _cut(diamondCutFacet, cut, boringOwnableFacet, abi.encodeWithSignature("initialize()"));
    }

    function _cut(
        address diamondCutFacet,
        IDiamondCut.FacetCut[] memory facetCuts,
        address _init,
        bytes memory _calldata
    ) internal {
        (bool success, bytes memory returnData) = address(diamondCutFacet).delegatecall(
            abi.encodeWithSelector(IDiamondCut.diamondCut.selector, facetCuts, _init, _calldata)
        );
        require(success, string(returnData));
    }

    function _implementation() internal view override returns (address) {
        return selectorToFacetAndIndex[msg.sig].facet;
    }
}
