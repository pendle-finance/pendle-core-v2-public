// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../../interfaces/IDiamondLoupe.sol";
import "./StaticAddRemoveLiqFacet.sol";
import "./StaticMarketInfoFacet.sol";
import "./StaticMintRedeemFacet.sol";
import "./StaticSwapFacet.sol";
import "./StaticVePendleFacet.sol";
import "../../core/libraries/ArrayLib.sol";

// solhint-disable no-empty-blocks
contract PendleRouterStatic is IDiamondLoupe, Proxy {
    using ArrayLib for bytes4[];

    address internal immutable ADD_REMOVE_FACET;
    address internal immutable MARKET_INFO_FACET;
    address internal immutable MINT_REDEEM_FACET;
    address internal immutable SWAP_FACET;
    address internal immutable VE_PENDLE_FACET;

    constructor(
        address _ADD_REMOVE_FACET,
        address _MARKET_INFO_FACET,
        address _MINT_REDEEM_FACET,
        address _SWAP_FACET,
        address _VE_PENDLE_FACET
    ) {
        ADD_REMOVE_FACET = _ADD_REMOVE_FACET;
        MARKET_INFO_FACET = _MARKET_INFO_FACET;
        MINT_REDEEM_FACET = _MINT_REDEEM_FACET;
        SWAP_FACET = _SWAP_FACET;
        VE_PENDLE_FACET = _VE_PENDLE_FACET;
    }

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
    function facetFunctionSelectors(address facet) public view returns (bytes4[] memory res) {
        if (facet == ADD_REMOVE_FACET) {
            res = new bytes4[](11);
            res[0] = StaticAddRemoveLiqFacet.addLiquidityDualSyAndPtStatic.selector;
            res[1] = StaticAddRemoveLiqFacet.addLiquidityDualTokenAndPtStatic.selector;
            res[2] = StaticAddRemoveLiqFacet.addLiquiditySinglePtStatic.selector;
            res[3] = StaticAddRemoveLiqFacet.addLiquiditySingleSyStatic.selector;
            res[4] = StaticAddRemoveLiqFacet.addLiquiditySingleTokenInStatic.selector;
            res[5] = StaticAddRemoveLiqFacet.removeLiquidityDualSyAndPtStatic.selector;
            res[6] = StaticAddRemoveLiqFacet.removeLiquidityDualTokenAndPtStatic.selector;
            res[7] = StaticAddRemoveLiqFacet.removeLiquiditySinglePtStatic.selector;
            res[8] = StaticAddRemoveLiqFacet.removeLiquiditySingleSyStatic.selector;
            res[9] = StaticAddRemoveLiqFacet.removeLiquiditySingleTokenOutStatic.selector;
            res[10] = StaticAddRemoveLiqFacet.getSyMarket.selector;
        } else if (facet == MARKET_INFO_FACET) {
            res = new bytes4[](14);
            res[0] = StaticMarketInfoFacet.getPYInfo.selector;
            res[1] = StaticMarketInfoFacet.getPY.selector;
            res[2] = StaticMarketInfoFacet.getMarketInfo.selector;
            res[3] = StaticMarketInfoFacet.getTokensInOut.selector;
            res[4] = StaticMarketInfoFacet.getUserSYInfo.selector;
            res[5] = StaticMarketInfoFacet.getUserPYInfo.selector;
            res[6] = StaticMarketInfoFacet.getUserMarketInfo.selector;
            res[7] = StaticMarketInfoFacet.getDefaultApproxParams.selector;
            res[8] = StaticMarketInfoFacet.getPtImpliedYield.selector;
            res[9] = StaticMarketInfoFacet.pyIndex.selector;
            res[10] = StaticMarketInfoFacet.getExchangeRate.selector;
            res[11] = StaticMarketInfoFacet.getTradeExchangeRateIncludeFee.selector;
            res[12] = StaticMarketInfoFacet.getTradeExchangeRateExcludeFee.selector;
            res[13] = StaticMarketInfoFacet.calcPriceImpact.selector;
        } else if (facet == MINT_REDEEM_FACET) {
            res = new bytes4[](8);
            res[0] = StaticMintRedeemFacet.mintPYFromSyStatic.selector;
            res[1] = StaticMintRedeemFacet.redeemPYToSyStatic.selector;
            res[2] = StaticMintRedeemFacet.mintPYFromBaseStatic.selector;
            res[3] = StaticMintRedeemFacet.redeemPYToBaseStatic.selector;
            res[4] = StaticMintRedeemFacet.previewDepositStatic.selector;
            res[5] = StaticMintRedeemFacet.previewRedeemStatic.selector;
            res[6] = StaticMintRedeemFacet.getAmountTokenToMintSy.selector;
            res[7] = StaticMintRedeemFacet.getAmountSyToRedeemToken.selector;
        } else if (facet == SWAP_FACET) {
            res = new bytes4[](15);
            res[0] = StaticSwapFacet.getSyMarket.selector;
            res[1] = StaticSwapFacet.swapExactPtForSyStatic.selector;
            res[2] = StaticSwapFacet.swapSyForExactPtStatic.selector;
            res[3] = StaticSwapFacet.swapExactSyForPtStatic.selector;
            res[4] = StaticSwapFacet.swapPtForExactSyStatic.selector;
            res[5] = StaticSwapFacet.swapExactTokenInForPtStatic.selector;
            res[6] = StaticSwapFacet.swapExactPtForTokenOutStatic.selector;
            res[7] = StaticSwapFacet.swapSyForExactYtStatic.selector;
            res[8] = StaticSwapFacet.swapExactSyForYtStatic.selector;
            res[9] = StaticSwapFacet.swapExactYtForSyStatic.selector;
            res[10] = StaticSwapFacet.swapYtForExactSyStatic.selector;
            res[11] = StaticSwapFacet.swapExactYtForTokenOutStatic.selector;
            res[12] = StaticSwapFacet.swapExactTokenInForYtStatic.selector;
            res[13] = StaticSwapFacet.swapExactPtForYtStatic.selector;
            res[14] = StaticSwapFacet.swapExactYtForPtStatic.selector;
        } else if (facet == VE_PENDLE_FACET) {
            res = new bytes4[](1);
            res[0] = StaticVePendleFacet.increaseLockPositionStatic.selector;
        } else {
            revert("INVALID_FACET");
        }
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() public view returns (address[] memory facetAddresses_) {
        facetAddresses_ = new address[](5);
        facetAddresses_[0] = ADD_REMOVE_FACET;
        facetAddresses_[1] = MARKET_INFO_FACET;
        facetAddresses_[2] = MINT_REDEEM_FACET;
        facetAddresses_[3] = SWAP_FACET;
        facetAddresses_[4] = VE_PENDLE_FACET;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param selector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 selector) public view returns (address) {
        Facet[] memory facets_ = facets();

        for (uint256 i = 0; i < facets_.length; i++) {
            if (facets_[i].functionSelectors.contains(selector)) {
                return facets_[i].facetAddress;
            }
        }
        return address(0);
    }

    function _implementation() internal view override returns (address) {
        return facetAddress(msg.sig);
    }
}
