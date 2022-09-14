// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../interfaces/IPAllAction.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../periphery/BoringOwnableUpgradeable.sol";

/// @dev this contract will be deployed behind an ERC1967 proxy
/// calls to the ERC1967 proxy will be resolved at this contract, and proxied again to the
/// corresponding implementation contracts

// solhint-disable no-empty-blocks
contract PendleRouter is Proxy, Initializable, UUPSUpgradeable, BoringOwnableUpgradeable {
    address public immutable ACTION_MINT_REDEEM;
    address public immutable ACTION_ADD_REMOVE_LIQ;
    address public immutable ACTION_SWAP_PT;
    address public immutable ACTION_SWAP_YT;
    address public immutable ACTION_SWAP_PTYT;
    address public immutable ACTION_CALLBACK;
    address public immutable ACTION_MISC;

    constructor(
        address _ACTION_MINT_REDEEM,
        address _ACTION_ADD_REMOVE_LIQ,
        address _ACTION_SWAP_PT,
        address _ACTION_SWAP_YT,
        address _ACTION_SWAP_PTYT,
        address _ACTION_CALLBACK,
        address _ACTION_MISC
    ) initializer {
        ACTION_MINT_REDEEM = _ACTION_MINT_REDEEM;
        ACTION_ADD_REMOVE_LIQ = _ACTION_ADD_REMOVE_LIQ;
        ACTION_SWAP_PT = _ACTION_SWAP_PT;
        ACTION_SWAP_YT = _ACTION_SWAP_YT;
        ACTION_SWAP_PTYT = _ACTION_SWAP_PTYT;
        ACTION_CALLBACK = _ACTION_CALLBACK;
        ACTION_MISC = _ACTION_MISC;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function getRouterImplementation(bytes4 sig) public view returns (address) {
        if (
            sig == IPActionMintRedeem.mintScyFromToken.selector ||
            sig == IPActionMintRedeem.redeemScyToToken.selector ||
            sig == IPActionMintRedeem.mintPyFromToken.selector ||
            sig == IPActionMintRedeem.redeemPyToToken.selector ||
            sig == IPActionMintRedeem.mintPyFromScy.selector ||
            sig == IPActionMintRedeem.redeemPyToScy.selector ||
            sig == IPActionMintRedeem.redeemDueInterestAndRewards.selector
        ) {
            return ACTION_MINT_REDEEM;
        } else if (
            sig == IPActionAddRemoveLiq.addLiquidityDualScyAndPt.selector ||
            sig == IPActionAddRemoveLiq.addLiquidityDualTokenAndPt.selector ||
            sig == IPActionAddRemoveLiq.addLiquiditySinglePt.selector ||
            sig == IPActionAddRemoveLiq.addLiquiditySingleScy.selector ||
            sig == IPActionAddRemoveLiq.addLiquiditySingleToken.selector ||
            sig == IPActionAddRemoveLiq.removeLiquidityDualScyAndPt.selector ||
            sig == IPActionAddRemoveLiq.removeLiquidityDualTokenAndPt.selector ||
            sig == IPActionAddRemoveLiq.removeLiquiditySinglePt.selector ||
            sig == IPActionAddRemoveLiq.removeLiquiditySingleScy.selector ||
            sig == IPActionAddRemoveLiq.removeLiquiditySingleToken.selector
        ) {
            return ACTION_ADD_REMOVE_LIQ;
        } else if (
            sig == IPActionSwapPT.swapExactPtForScy.selector ||
            sig == IPActionSwapPT.swapPtForExactScy.selector ||
            sig == IPActionSwapPT.swapScyForExactPt.selector ||
            sig == IPActionSwapPT.swapExactScyForPt.selector ||
            sig == IPActionSwapPT.swapExactTokenForPt.selector ||
            sig == IPActionSwapPT.swapExactPtForToken.selector
        ) {
            return ACTION_SWAP_PT;
        } else if (
            sig == IPActionSwapYT.swapExactYtForScy.selector ||
            sig == IPActionSwapYT.swapScyForExactYt.selector ||
            sig == IPActionSwapYT.swapExactScyForYt.selector ||
            sig == IPActionSwapYT.swapExactTokenForYt.selector ||
            sig == IPActionSwapYT.swapExactYtForToken.selector ||
            sig == IPActionSwapYT.swapYtForExactScy.selector
        ) {
            return ACTION_SWAP_YT;
        } else if (
            sig == IPActionSwapPTYT.swapExactPtForYt.selector ||
            sig == IPActionSwapPTYT.swapExactYtForPt.selector
        ) {
            return ACTION_SWAP_PTYT;
        } else if (sig == IPMarketSwapCallback.swapCallback.selector) {
            return ACTION_CALLBACK;
        } else if (sig == IPActionMisc.consult.selector) {
            return ACTION_MISC;
        }
        require(false, "invalid market sig");
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _implementation() internal view override returns (address) {
        return getRouterImplementation(msg.sig);
    }
}
