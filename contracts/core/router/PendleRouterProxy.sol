// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../misc/BoringOwnableUpg.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../../interfaces/IPRouterCore.sol";
import "../../interfaces/IPRouterYT.sol";

/// @dev this contract will be deployed behind an ERC1967 proxy
/// calls to the ERC1967 proxy will be resolved at this contract, and proxied again to the
/// corresponding implementation contracts
contract PendleRouterProxy is Proxy, Initializable, UUPSUpgradeable, BoringOwnableUpg {
    address public immutable PENDLE_ROUTER_CORE;
    address public immutable PENDLE_ROUTER_YT;

    constructor(address _PENDLE_ROUTER_CORE, address _PENDLE_ROUTER_YT) {
        PENDLE_ROUTER_CORE = _PENDLE_ROUTER_CORE;
        PENDLE_ROUTER_YT = _PENDLE_ROUTER_YT;
    }

    function initialize() external initializer {
        __UUPSUpgradeable_init();
        __BoringOwnable_init();
    }

    function getRouterImplementation(bytes4 sig) public view returns (address) {
        if (
            sig == IPRouterCore.mintScyFromRawToken.selector ||
            sig == IPRouterCore.redeemScyToRawToken.selector ||
            sig == IPRouterCore.mintYoFromRawToken.selector ||
            sig == IPRouterCore.redeemYoToRawToken.selector ||
            sig == IPRouterCore.addLiquidity.selector ||
            sig == IPRouterCore.removeLiquidity.selector ||
            sig == IPRouterCore.swapExactOtForScy.selector ||
            sig == IPRouterCore.swapOtForExactScy.selector ||
            sig == IPRouterCore.swapScyForExactOt.selector ||
            sig == IPRouterCore.swapExactScyForOt.selector ||
            sig == IPRouterCore.swapExactRawTokenForOt.selector ||
            sig == IPRouterCore.swapExactOtForRawToken.selector
        ) {
            return PENDLE_ROUTER_CORE;
        } else if (
            sig == IPRouterYT.swapExactYtForScy.selector ||
            sig == IPRouterYT.swapScyForExactYt.selector ||
            sig == IPRouterYT.swapExactScyForYt.selector ||
            sig == IPRouterYT.swapExactRawTokenForYt.selector ||
            sig == IPRouterYT.swapExactYtForRawToken.selector
        ) {
            return PENDLE_ROUTER_YT;
        } else if (sig == IPMarketSwapCallback.swapCallback.selector) {
            // only ROUTER_YT is doing callback
            return PENDLE_ROUTER_YT;
        }
        require(false, "invalid market sig");
    }

    function _implementation() internal view override returns (address) {
        return getRouterImplementation(msg.sig);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
