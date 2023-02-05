// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../interfaces/IPAllAction.sol";
import "../interfaces/IDiamondLoupe.sol";
import "../interfaces/IDiamondCut.sol";

// solhint-disable no-empty-blocks
contract PendleRouter is Proxy, IDiamondLoupe {
    address internal immutable ACTION_MINT_REDEEM;
    address internal immutable ACTION_ADD_REMOVE_LIQ;
    address internal immutable ACTION_SWAP_PT;
    address internal immutable ACTION_SWAP_YT;
    address internal immutable ACTION_MISC;

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    constructor(
        address _ACTION_MINT_REDEEM,
        address _ACTION_ADD_REMOVE_LIQ,
        address _ACTION_SWAP_PT,
        address _ACTION_SWAP_YT,
        address _ACTION_MISC
    ) {
        ACTION_MINT_REDEEM = _ACTION_MINT_REDEEM;
        ACTION_ADD_REMOVE_LIQ = _ACTION_ADD_REMOVE_LIQ;
        ACTION_SWAP_PT = _ACTION_SWAP_PT;
        ACTION_SWAP_YT = _ACTION_SWAP_YT;
        ACTION_MISC = _ACTION_MISC;
        _emitEvents();
    }

    function _emitEvents() internal {
        Facet[] memory facets_ = facets();

        uint256 nFacets = facets_.length;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](nFacets);
        for (uint256 i; i < nFacets; ) {
            cuts[i].facetAddress = facets_[i].facetAddress;
            cuts[i].action = IDiamondCut.FacetCutAction.Add;
            cuts[i].functionSelectors = facets_[i].functionSelectors;
            unchecked {
                ++i;
            }
        }

        emit DiamondCut(cuts, address(0), "");
    }

    receive() external payable virtual override {}

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() public view returns (Facet[] memory facets_) {
        address[] memory facetAddresses_ = facetAddresses();
        uint256 numFacets = facetAddresses_.length;

        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; ) {
            facets_[i].facetAddress = facetAddresses_[i];
            facets_[i].functionSelectors = facetFunctionSelectors(facetAddresses_[i]);
            unchecked {
                i++;
            }
        }
    }

    /// @notice Gets all the function selectors supported by a specific facet.
    function facetFunctionSelectors(address facet) public view returns (bytes4[] memory res) {}

    function facetAddress(bytes4 sig) public view returns (address) {
        if (sig < 0x85b29936) {
            if (sig < 0x409c7a89) {
                if (sig < 0x2032aecd) {
                    if (sig == 0x015491d1) return ACTION_ADD_REMOVE_LIQ; // addLiquiditySingleToken 4
                    if (sig == 0x178d29d3) return ACTION_ADD_REMOVE_LIQ; // removeLiquiditySingleSy 5
                    if (sig == 0x1a8631b2) return ACTION_MINT_REDEEM; // mintPyFromSy 6
                } else {
                    if (sig == 0x2032aecd) return ACTION_SWAP_PT; // swapExactPtForSy 4
                    if (sig == 0x339748cb) return ACTION_MINT_REDEEM; // redeemPyToSy 5
                    if (sig == 0x357d6540) return ACTION_SWAP_YT; // swapExactYtForSy 6
                    if (sig == 0x3af1f329) return ACTION_ADD_REMOVE_LIQ; // addLiquiditySinglePt 7
                }
            } else {
                if (sig < 0x527df199) {
                    if (sig == 0x409c7a89) return ACTION_ADD_REMOVE_LIQ; // addLiquiditySingleSy 4
                    if (sig == 0x443e6512) return ACTION_MINT_REDEEM; // mintSyFromToken 5
                    if (sig == 0x448b9b95) return ACTION_SWAP_YT; // swapExactYtForPt 6
                    if (sig == 0x46eb2db6) return ACTION_MINT_REDEEM; // mintPyFromToken 7
                } else {
                    if (sig < 0x694ab559) {
                        if (sig == 0x527df199) return ACTION_MINT_REDEEM; // redeemPyToToken 5
                        if (sig == 0x690807ad) return ACTION_ADD_REMOVE_LIQ; // removeLiquiditySingleToken 6
                    } else {
                        if (sig == 0x694ab559) return ACTION_ADD_REMOVE_LIQ; // removeLiquiditySinglePt 5
                        if (sig == 0x6b8bdf32) return ACTION_SWAP_PT; // swapSyForExactPt 6
                        if (sig == 0x83c71b69) return ACTION_SWAP_PT; // swapExactSyForPt 7
                    }
                }
            }
        } else {
            if (sig < 0xc861a898) {
                if (sig < 0xacdb32df) {
                    if (sig == 0x85b29936) return ACTION_MINT_REDEEM; // redeemSyToToken 4
                    if (sig == 0x97ee279e) return ACTION_ADD_REMOVE_LIQ; // addLiquidityDualSyAndPt 5
                    if (sig == 0xa5f9931b) return ACTION_SWAP_PT; // swapExactTokenForPt 6
                } else {
                    if (sig < 0xb85f50ba) {
                        if (sig == 0xacdb32df) return ACTION_MISC; // approveInf 5
                        if (sig == 0xb7d75b8b) return ACTION_ADD_REMOVE_LIQ; // removeLiquidityDualSyAndPt 6
                    } else {
                        if (sig == 0xb85f50ba) return ACTION_SWAP_PT; // swapExactPtForToken 5
                        if (sig == 0xbf1bd434) return ACTION_SWAP_YT; // swapSyForExactYt 6
                        if (sig == 0xc4a9c7de) return ACTION_SWAP_YT; // swapExactTokenForYt 7
                    }
                }
            } else {
                if (sig < 0xe15cc098) {
                    if (sig == 0xc861a898) return ACTION_SWAP_YT; // swapExactPtForYt 4
                    if (sig == 0xcb591eb2) return ACTION_ADD_REMOVE_LIQ; // addLiquidityDualTokenAndPt 5
                    if (sig == 0xd6308fa4) return ACTION_SWAP_YT; // swapExactYtForToken 6
                    if (sig == 0xdd371acd) return ACTION_SWAP_PT; // swapPtForExactSy 7
                } else {
                    if (sig < 0xf7e375e8) {
                        if (sig == 0xe15cc098) return ACTION_SWAP_YT; // swapYtForExactSy 5
                        if (sig == 0xe6eaba01) return ACTION_ADD_REMOVE_LIQ; // removeLiquidityDualTokenAndPt 6
                    } else {
                        if (sig == 0xf7e375e8) return ACTION_MINT_REDEEM; // redeemDueInterestAndRewards 5
                        if (sig == 0xfa483e72) return ACTION_SWAP_YT; // swapCallback 6
                        if (sig == 0xfdd71f43) return ACTION_SWAP_YT; // swapExactSyForYt 7
                    }
                }
            }
        }

        revert Errors.RouterInvalidAction(sig);
    }

    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](5);
        facetAddresses_[0] = ACTION_ADD_REMOVE_LIQ;
        facetAddresses_[1] = ACTION_MINT_REDEEM;
        facetAddresses_[2] = ACTION_SWAP_PT;
        facetAddresses_[3] = ACTION_SWAP_YT;
        facetAddresses_[4] = ACTION_MISC;
    }

    function _implementation() internal view override returns (address) {
        return facetAddress(msg.sig);
    }
}
