// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../interfaces/IPAllAction.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../core/libraries/Errors.sol";

/// @dev this contract will be deployed behind an ERC1967 proxy
/// calls to the ERC1967 proxy will be resolved at this contract, and proxied again to the
/// corresponding implementation contracts

// solhint-disable no-empty-blocks
contract PendleRouter is Proxy {
    address internal immutable ACTION_MINT_REDEEM;
    address internal immutable ACTION_ADD_REMOVE_LIQ;
    address internal immutable ACTION_SWAP_PT;
    address internal immutable ACTION_SWAP_YT;
    address internal immutable ACTION_SWAP_PTYT;
    address internal immutable ACTION_CALLBACK;
    address internal immutable ACTION_MISC;

    constructor(
        address _ACTION_MINT_REDEEM,
        address _ACTION_ADD_REMOVE_LIQ,
        address _ACTION_SWAP_PT,
        address _ACTION_SWAP_YT,
        address _ACTION_SWAP_PTYT,
        address _ACTION_CALLBACK,
        address _ACTION_MISC
    ) {
        ACTION_MINT_REDEEM = _ACTION_MINT_REDEEM;
        ACTION_ADD_REMOVE_LIQ = _ACTION_ADD_REMOVE_LIQ;
        ACTION_SWAP_PT = _ACTION_SWAP_PT;
        ACTION_SWAP_YT = _ACTION_SWAP_YT;
        ACTION_SWAP_PTYT = _ACTION_SWAP_PTYT;
        ACTION_CALLBACK = _ACTION_CALLBACK;
        ACTION_MISC = _ACTION_MISC;
    }

    receive() external payable virtual override {}

    // prettier-ignore
    /// @dev selectors are ordered by frequency of usage
    function getRouterImplementation(bytes4 sig) public view returns (address) {
        if (sig == IPActionAddRemoveLiq.addLiquiditySingleToken.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionMintRedeem.redeemDueInterestAndRewards.selector) return ACTION_MINT_REDEEM;
        if (sig == IPMarketSwapCallback.swapCallback.selector) return ACTION_CALLBACK;
        if (sig == IPActionSwapYT.swapExactTokenForYt.selector) return ACTION_SWAP_YT;
        if (sig == IPActionAddRemoveLiq.removeLiquiditySingleToken.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionMintRedeem.mintPyFromToken.selector) return ACTION_MINT_REDEEM;

        if (sig == IPActionSwapPT.swapExactTokenForPt.selector) return ACTION_SWAP_PT;
        if (sig == IPActionSwapYT.swapExactSyForYt.selector) return ACTION_SWAP_YT;
        if (sig == IPActionAddRemoveLiq.addLiquidityDualTokenAndPt.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionSwapYT.swapExactYtForToken.selector) return ACTION_SWAP_YT;
        if (sig == IPActionSwapYT.swapExactYtForSy.selector) return ACTION_SWAP_YT;

        if (sig == IPActionSwapPT.swapExactPtForToken.selector) return ACTION_SWAP_PT;
        if (sig == IPActionAddRemoveLiq.addLiquiditySinglePt.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionMintRedeem.redeemPyToToken.selector) return ACTION_MINT_REDEEM;
        if (sig == IPActionAddRemoveLiq.addLiquidityDualSyAndPt.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionSwapPTYT.swapExactPtForYt.selector) return ACTION_SWAP_PTYT;

        if (sig == IPActionAddRemoveLiq.removeLiquidityDualSyAndPt.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionMintRedeem.mintPyFromSy.selector) return ACTION_MINT_REDEEM;
        if (sig == IPActionSwapPT.swapExactSyForPt.selector) return ACTION_SWAP_PT;
        if (sig == IPActionAddRemoveLiq.addLiquiditySingleSy.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionMintRedeem.mintSyFromToken.selector) return ACTION_MINT_REDEEM;

        if (sig == IPActionAddRemoveLiq.removeLiquidityDualTokenAndPt.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionSwapPTYT.swapExactYtForPt.selector) return ACTION_SWAP_PTYT;
        if (sig == IPActionSwapPT.swapExactPtForSy.selector) return ACTION_SWAP_PT;
        if (sig == IPActionMintRedeem.redeemPyToSy.selector) return ACTION_MINT_REDEEM;
        if (sig == IPActionAddRemoveLiq.removeLiquiditySingleSy.selector) return ACTION_ADD_REMOVE_LIQ;

        if (sig == IPActionAddRemoveLiq.removeLiquiditySinglePt.selector) return ACTION_ADD_REMOVE_LIQ;
        if (sig == IPActionMintRedeem.redeemSyToToken.selector) return ACTION_MINT_REDEEM;
        if (sig == IPActionSwapPT.swapPtForExactSy.selector) return ACTION_SWAP_PT;
        if (sig == IPActionSwapPT.swapSyForExactPt.selector) return ACTION_SWAP_PT;
        if (sig == IPActionSwapYT.swapSyForExactYt.selector) return ACTION_SWAP_YT;

        if (sig == IPActionSwapYT.swapYtForExactSy.selector) return ACTION_SWAP_YT;
        if (sig == IPActionMisc.approveInf.selector) return ACTION_MISC;

        revert Errors.RouterInvalidAction(sig);
    }

    function _implementation() internal view override returns (address) {
        return getRouterImplementation(msg.sig);
    }
}
