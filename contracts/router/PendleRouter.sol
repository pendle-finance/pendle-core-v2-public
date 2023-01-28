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

    function getRouterImplementation(bytes4 sig) public view returns (address) {
        if (
            sig == IPActionMintRedeem.mintSyFromToken.selector ||
            sig == IPActionMintRedeem.redeemSyToToken.selector ||
            sig == IPActionMintRedeem.mintPyFromToken.selector ||
            sig == IPActionMintRedeem.redeemPyToToken.selector ||
            sig == IPActionMintRedeem.mintPyFromSy.selector ||
            sig == IPActionMintRedeem.redeemPyToSy.selector ||
            sig == IPActionMintRedeem.redeemDueInterestAndRewards.selector ||
            sig == IPActionMintRedeem.redeemDueInterestAndRewardsThenSwapAll.selector
        ) {
            return ACTION_MINT_REDEEM;
        }
        if (
            sig == IPActionAddRemoveLiq.addLiquidityDualSyAndPt.selector ||
            sig == IPActionAddRemoveLiq.addLiquidityDualTokenAndPt.selector ||
            sig == IPActionAddRemoveLiq.addLiquiditySinglePt.selector ||
            sig == IPActionAddRemoveLiq.addLiquiditySingleSy.selector ||
            sig == IPActionAddRemoveLiq.addLiquiditySingleToken.selector ||
            sig == IPActionAddRemoveLiq.removeLiquidityDualSyAndPt.selector ||
            sig == IPActionAddRemoveLiq.removeLiquidityDualTokenAndPt.selector ||
            sig == IPActionAddRemoveLiq.removeLiquiditySinglePt.selector ||
            sig == IPActionAddRemoveLiq.removeLiquiditySingleSy.selector ||
            sig == IPActionAddRemoveLiq.removeLiquiditySingleToken.selector
        ) {
            return ACTION_ADD_REMOVE_LIQ;
        }
        if (
            sig == IPActionSwapPT.swapExactPtForSy.selector ||
            sig == IPActionSwapPT.swapPtForExactSy.selector ||
            sig == IPActionSwapPT.swapSyForExactPt.selector ||
            sig == IPActionSwapPT.swapExactSyForPt.selector ||
            sig == IPActionSwapPT.swapExactTokenForPt.selector ||
            sig == IPActionSwapPT.swapExactPtForToken.selector
        ) {
            return ACTION_SWAP_PT;
        }
        if (
            sig == IPActionSwapYT.swapExactYtForSy.selector ||
            sig == IPActionSwapYT.swapSyForExactYt.selector ||
            sig == IPActionSwapYT.swapExactSyForYt.selector ||
            sig == IPActionSwapYT.swapExactTokenForYt.selector ||
            sig == IPActionSwapYT.swapExactYtForToken.selector ||
            sig == IPActionSwapYT.swapYtForExactSy.selector
        ) {
            return ACTION_SWAP_YT;
        }
        if (
            sig == IPActionSwapPTYT.swapExactPtForYt.selector ||
            sig == IPActionSwapPTYT.swapExactYtForPt.selector
        ) {
            return ACTION_SWAP_PTYT;
        }
        if (sig == IPMarketSwapCallback.swapCallback.selector) {
            return ACTION_CALLBACK;
        }
        if (sig == IPActionMisc.consult.selector || sig == IPActionMisc.approveInf.selector) {
            return ACTION_MISC;
        }
        revert Errors.RouterInvalidAction(sig);
    }

    function _implementation() internal view override returns (address) {
        return getRouterImplementation(msg.sig);
    }
}
