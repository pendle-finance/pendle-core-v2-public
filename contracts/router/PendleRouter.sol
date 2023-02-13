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

    function facetFunctionSelectors(address facet) public view returns (bytes4[] memory res) {
        if (facet == ACTION_ADD_REMOVE_LIQ) {
            res = new bytes4[](12);
            res[0] = 0x97ee279e; // addLiquidityDualSyAndPt
            res[1] = 0xcb591eb2; // addLiquidityDualTokenAndPt
            res[2] = 0x3af1f329; // addLiquiditySinglePt
            res[3] = 0x409c7a89; // addLiquiditySingleSy
            res[4] = 0x015491d1; // addLiquiditySingleToken
            res[5] = 0xb7d75b8b; // removeLiquidityDualSyAndPt
            res[6] = 0xe6eaba01; // removeLiquidityDualTokenAndPt
            res[7] = 0x694ab559; // removeLiquiditySinglePt
            res[8] = 0x178d29d3; // removeLiquiditySingleSy
            res[9] = 0x690807ad; // removeLiquiditySingleToken
            res[10] = 0xdfbc814e; // addLiquiditySingleTokenKeepYt
            res[11] = 0x844384aa; // addLiquiditySingleSyKeepYt
            return res;
        }
        if (facet == ACTION_MINT_REDEEM) {
            res = new bytes4[](7);
            res[0] = 0x1a8631b2; // mintPyFromSy
            res[1] = 0x46eb2db6; // mintPyFromToken
            res[2] = 0x443e6512; // mintSyFromToken
            res[3] = 0xf7e375e8; // redeemDueInterestAndRewards
            res[4] = 0x339748cb; // redeemPyToSy
            res[5] = 0x527df199; // redeemPyToToken
            res[6] = 0x85b29936; // redeemSyToToken
            return res;
        }
        if (facet == ACTION_SWAP_PT) {
            res = new bytes4[](6);
            res[0] = 0x2032aecd; // swapExactPtForSy
            res[1] = 0xb85f50ba; // swapExactPtForToken
            res[2] = 0x83c71b69; // swapExactSyForPt
            res[3] = 0xa5f9931b; // swapExactTokenForPt
            res[4] = 0xdd371acd; // swapPtForExactSy
            res[5] = 0x6b8bdf32; // swapSyForExactPt
            return res;
        }
        if (facet == ACTION_SWAP_YT) {
            res = new bytes4[](9);
            res[0] = 0xfa483e72; // swapCallback
            res[1] = 0xc861a898; // swapExactPtForYt
            res[2] = 0x448b9b95; // swapExactYtForPt
            res[3] = 0xfdd71f43; // swapExactSyForYt
            res[4] = 0xc4a9c7de; // swapExactTokenForYt
            res[5] = 0x357d6540; // swapExactYtForSy
            res[6] = 0xd6308fa4; // swapExactYtForToken
            res[7] = 0xbf1bd434; // swapSyForExactYt
            res[8] = 0xe15cc098; // swapYtForExactSy
            return res;
        }
        if (facet == ACTION_MISC) {
            res = new bytes4[](2);
            res[0] = 0xacdb32df; // approveInf
            res[1] = 0xd617b03b; // batchExec
            return res;
        }
        if (facet == address(this)) {
            res = new bytes4[](4);
            res[0] = 0xcdffacc6; // facetAddress
            res[1] = 0x52ef6b2c; // facetAddresses
            res[2] = 0xadfca15e; // facetFunctionSelectors
            res[3] = 0x7a0ed627; // facets
            return res;
        }
        revert Errors.RouterInvalidFacet(facet);
    }

    function facetAddress(bytes4 sig) public view returns (address) {
        if (sig < 0x97ee279e) {
            if (sig < 0x46eb2db6) {
                if (sig < 0x357d6540) {
                    if (sig < 0x1a8631b2) {
                        if (sig == 0x015491d1) return ACTION_ADD_REMOVE_LIQ; // addLiquiditySingleToken 5
                        if (sig == 0x178d29d3) return ACTION_ADD_REMOVE_LIQ; // removeLiquiditySingleSy 6
                    } else {
                        if (sig == 0x1a8631b2) return ACTION_MINT_REDEEM; // mintPyFromSy 5
                        if (sig == 0x2032aecd) return ACTION_SWAP_PT; // swapExactPtForSy 6
                        if (sig == 0x339748cb) return ACTION_MINT_REDEEM; // redeemPyToSy 7
                    }
                } else {
                    if (sig < 0x409c7a89) {
                        if (sig == 0x357d6540) return ACTION_SWAP_YT; // swapExactYtForSy 5
                        if (sig == 0x3af1f329) return ACTION_ADD_REMOVE_LIQ; // addLiquiditySinglePt 6
                    } else {
                        if (sig == 0x409c7a89) return ACTION_ADD_REMOVE_LIQ; // addLiquiditySingleSy 5
                        if (sig == 0x443e6512) return ACTION_MINT_REDEEM; // mintSyFromToken 6
                        if (sig == 0x448b9b95) return ACTION_SWAP_YT; // swapExactYtForPt 7
                    }
                }
            } else {
                if (sig < 0x6b8bdf32) {
                    if (sig < 0x52ef6b2c) {
                        if (sig == 0x46eb2db6) return ACTION_MINT_REDEEM; // mintPyFromToken 5
                        if (sig == 0x527df199) return ACTION_MINT_REDEEM; // redeemPyToToken 6
                    } else {
                        if (sig == 0x690807ad) return ACTION_ADD_REMOVE_LIQ; // removeLiquiditySingleToken 5
                        if (sig == 0x694ab559) return ACTION_ADD_REMOVE_LIQ; // removeLiquiditySinglePt 6
                        if (sig == 0x52ef6b2c) return address(this); // facetAddresses 7
                    }
                } else {
                    if (sig < 0x83c71b69) {
                        if (sig == 0x6b8bdf32) return ACTION_SWAP_PT; // swapSyForExactPt 5
                        if (sig == 0x7a0ed627) return address(this); // facets 6
                    } else {
                        if (sig == 0x85b29936) return ACTION_MINT_REDEEM; // redeemSyToToken 5
                        if (sig == 0x844384aa) return ACTION_ADD_REMOVE_LIQ; // addLiquiditySingleSyKeepYt 6
                        if (sig == 0x83c71b69) return ACTION_SWAP_PT; // swapExactSyForPt 7
                    }
                }
            }
        } else {
            if (sig < 0xcdffacc6) {
                if (sig < 0xb85f50ba) {
                    if (sig < 0xacdb32df) {
                        if (sig == 0xa5f9931b) return ACTION_SWAP_PT; // swapExactTokenForPt 5
                        if (sig == 0x97ee279e) return ACTION_ADD_REMOVE_LIQ; // addLiquidityDualSyAndPt 6
                    } else {
                        if (sig == 0xb7d75b8b) return ACTION_ADD_REMOVE_LIQ; // removeLiquidityDualSyAndPt 5
                        if (sig == 0xacdb32df) return ACTION_MISC; // approveInf 6
                        if (sig == 0xadfca15e) return address(this); // facetFunctionSelectors 7
                    }
                } else {
                    if (sig < 0xc4a9c7de) {
                        if (sig == 0xb85f50ba) return ACTION_SWAP_PT; // swapExactPtForToken 5
                        if (sig == 0xbf1bd434) return ACTION_SWAP_YT; // swapSyForExactYt 6
                    } else {
                        if (sig == 0xc4a9c7de) return ACTION_SWAP_YT; // swapExactTokenForYt 5
                        if (sig == 0xcb591eb2) return ACTION_ADD_REMOVE_LIQ; // addLiquidityDualTokenAndPt 6
                        if (sig == 0xc861a898) return ACTION_SWAP_YT; // swapExactPtForYt 7
                    }
                }
            } else {
                if (sig < 0xe15cc098) {
                    if (sig < 0xd6308fa4) {
                        if (sig == 0xd617b03b) return ACTION_MISC; // batchExec 5
                        if (sig == 0xcdffacc6) return address(this); // facetAddress 6
                    } else {
                        if (sig == 0xd6308fa4) return ACTION_SWAP_YT; // swapExactYtForToken 5
                        if (sig == 0xdfbc814e) return ACTION_ADD_REMOVE_LIQ; // addLiquiditySingleTokenKeepYt 6
                        if (sig == 0xdd371acd) return ACTION_SWAP_PT; // swapPtForExactSy 7
                    }
                } else {
                    if (sig < 0xf7e375e8) {
                        if (sig == 0xe6eaba01) return ACTION_ADD_REMOVE_LIQ; // removeLiquidityDualTokenAndPt 5
                        if (sig == 0xe15cc098) return ACTION_SWAP_YT; // swapYtForExactSy 6
                    } else {
                        if (sig == 0xfa483e72) return ACTION_SWAP_YT; // swapCallback 5
                        if (sig == 0xf7e375e8) return ACTION_MINT_REDEEM; // redeemDueInterestAndRewards 6
                        if (sig == 0xfdd71f43) return ACTION_SWAP_YT; // swapExactSyForYt 7
                    }
                }
            }
        }
        revert Errors.RouterInvalidAction(sig);
        // NUM_FUNC: 40 AVG:5.80 STD:0.75 WORST_CASE:7 STOP_BRANCH:3
    }

    function facetAddresses() public view returns (address[] memory) {
        address[] memory res = new address[](6);
        res[0] = ACTION_ADD_REMOVE_LIQ;
        res[1] = ACTION_MINT_REDEEM;
        res[2] = ACTION_SWAP_PT;
        res[3] = ACTION_SWAP_YT;
        res[4] = ACTION_MISC;
        res[5] = address(this);
        return res;
    }

    function _implementation() internal view override returns (address) {
        return facetAddress(msg.sig);
    }
}
