// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../../interfaces/IDiamondLoupe.sol";
import "../../interfaces/IDiamondCut.sol";
import "./StaticAddRemoveLiqFacet.sol";
import "./StaticMarketInfoFacet.sol";
import "./StaticMintRedeemFacet.sol";
import "./StaticSwapFacet.sol";
import "./StaticVePendleFacet.sol";
import "./DiamondCutFacet.sol";
import "./BoringOwnableFacet.sol";
import "../../core/libraries/ArrayLib.sol";

// solhint-disable no-empty-blocks
contract PendleRouterStatic is Proxy, StorageLayout {
    constructor(address diamondCutFacet, address boringOwnableFacet) {
        _initDiamondCutFacet(diamondCutFacet);
        _initBoringOwnableFacet(diamondCutFacet, boringOwnableFacet);
    }

    function _initDiamondCutFacet(address diamondCutFacet) internal {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;

        cut[0] = IDiamondCut.FacetCut(diamondCutFacet, IDiamondCut.FacetCutAction.Add, selectors);
        _cut(diamondCutFacet, cut, address(0), "");
    }

    function _initBoringOwnableFacet(address diamondCutFacet, address boringOwnableFacet)
        internal
    {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = BoringOwnableFacet.transferOwnership.selector;
        selectors[1] = BoringOwnableFacet.claimOwnership.selector;

        cut[0] = IDiamondCut.FacetCut(
            boringOwnableFacet,
            IDiamondCut.FacetCutAction.Add,
            selectors
        );

        _cut(diamondCutFacet, cut, boringOwnableFacet, abi.encodeWithSignature("initialize()"));
    }

    function _cut(
        address diamondCutFacet,
        IDiamondCut.FacetCut[] memory facetCuts,
        address _init,
        bytes memory _calldata
    ) internal {
        (bool success, ) = address(diamondCutFacet).delegatecall(
            abi.encodeWithSelector(IDiamondCut.diamondCut.selector, facetCuts, _init, _calldata)
        );
        require(success);
    }

    function _implementation() internal view override returns (address) {
        return selectorToFacet[msg.sig];
    }
}
