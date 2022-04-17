// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../../interfaces/IPRouterCore.sol";
import "../../interfaces/IPRouterYT.sol";
import "../../interfaces/IPRouterStatic.sol";
import "../../periphery/PermissionsV2Upg.sol";

/// @dev this contract will be deployed behind an ERC1967 proxy
/// calls to the ERC1967 proxy will be resolved at this contract, and proxied again to the
/// corresponding implementation contracts
contract PendleRouterProxy is Proxy, Initializable, UUPSUpgradeable, PermissionsV2Upg {
    address public immutable PENDLE_ROUTER_CORE;
    address public immutable PENDLE_ROUTER_YT;
    address public immutable PENDLE_ROUTER_STATIC;

    constructor(
        address _PENDLE_ROUTER_CORE,
        address _PENDLE_ROUTER_YT,
        address _PENDLE_ROUTER_STATIC,
        address _governanceManager
    ) PermissionsV2Upg(_governanceManager) initializer {
        PENDLE_ROUTER_CORE = _PENDLE_ROUTER_CORE;
        PENDLE_ROUTER_YT = _PENDLE_ROUTER_YT;
        PENDLE_ROUTER_STATIC = _PENDLE_ROUTER_STATIC;
    }

    function initialize() external initializer {
        __UUPSUpgradeable_init();
        // no need to initialize PermissionsV2Upg
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
        /// FROM HERE ONWARDS, ONLY HAVE STATIC & VIEW FUNCTIONS
        else if (
            sig == IPRouterStatic.addLiquidityStatic.selector ||
            sig == IPRouterStatic.removeLiquidityStatic.selector ||
            sig == IPRouterStatic.swapOtForScyStatic.selector ||
            sig == IPRouterStatic.swapScyForOtStatic.selector ||
            sig == IPRouterStatic.scyIndex.selector ||
            sig == IPRouterStatic.getOtImpliedYield.selector ||
            sig == IPRouterStatic.getPendleTokenType.selector
        ) {
            return PENDLE_ROUTER_STATIC;
        }
        require(false, "invalid market sig");
    }

    function _implementation() internal view override returns (address) {
        return getRouterImplementation(msg.sig);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyGovernance {}
}
