// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "../interfaces/IPActionCore.sol";
import "../interfaces/IPActionYT.sol";
import "../interfaces/IPRouterStatic.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../periphery/PermissionsV2Upg.sol";

/// @dev this contract will be deployed behind an ERC1967 proxy
/// calls to the ERC1967 proxy will be resolved at this contract, and proxied again to the
/// corresponding implementation contracts

// solhint-disable no-empty-blocks
contract PendleRouter is Proxy, Initializable, UUPSUpgradeable, PermissionsV2Upg {
    address public immutable ACTION_CORE;
    address public immutable ACTION_YT;
    address public immutable ACTION_CALLBACK;

    constructor(
        address _ACTION_CORE,
        address _ACTION_YT,
        address _ACTION_CALLBACK,
        address _governanceManager
    ) PermissionsV2Upg(_governanceManager) initializer {
        require(
            _ACTION_CORE != address(0) &&
                _ACTION_YT != address(0) &&
                _ACTION_CALLBACK != address(0),
            "zero address"
        );
        ACTION_CORE = _ACTION_CORE;
        ACTION_YT = _ACTION_YT;
        ACTION_CALLBACK = _ACTION_CALLBACK;
    }

    function initialize() external initializer {
        __UUPSUpgradeable_init();
        // no need to initialize PermissionsV2Upg
    }

    function getRouterImplementation(bytes4 sig) public view returns (address) {
        if (
            sig == IPActionCore.mintScyFromToken.selector ||
            sig == IPActionCore.redeemScyToToken.selector ||
            sig == IPActionCore.mintPyFromToken.selector ||
            sig == IPActionCore.redeemPyToToken.selector ||
            sig == IPActionCore.mintPyFromScy.selector ||
            sig == IPActionCore.redeemPyToScy.selector ||
            sig == IPActionCore.addLiquidityDualScyAndPt.selector ||
            sig == IPActionCore.addLiquidityDualIbTokenAndPt.selector ||
            sig == IPActionCore.addLiquiditySinglePt.selector ||
            sig == IPActionCore.addLiquiditySingleScy.selector ||
            sig == IPActionCore.addLiquiditySingleToken.selector ||
            sig == IPActionCore.removeLiquidityDualScyAndPt.selector ||
            sig == IPActionCore.removeLiquidityDualIbTokenAndPt.selector ||
            sig == IPActionCore.removeLiquiditySinglePt.selector ||
            sig == IPActionCore.removeLiquiditySingleScy.selector ||
            sig == IPActionCore.removeLiquiditySingleToken.selector ||
            sig == IPActionCore.swapExactPtForScy.selector ||
            sig == IPActionCore.swapPtForExactScy.selector ||
            sig == IPActionCore.swapScyForExactPt.selector ||
            sig == IPActionCore.swapExactScyForPt.selector ||
            sig == IPActionCore.swapExactTokenForPt.selector ||
            sig == IPActionCore.swapExactPtForToken.selector ||
            sig == IPActionCore.redeemDueInterestAndRewards.selector
        ) {
            return ACTION_CORE;
        } else if (
            sig == IPActionYT.swapExactYtForScy.selector ||
            sig == IPActionYT.swapScyForExactYt.selector ||
            sig == IPActionYT.swapExactScyForYt.selector ||
            sig == IPActionYT.swapExactTokenForYt.selector ||
            sig == IPActionYT.swapExactYtForToken.selector ||
            sig == IPActionYT.swapYtForExactScy.selector
        ) {
            return ACTION_YT;
        } else if (sig == IPMarketSwapCallback.swapCallback.selector) {
            return ACTION_CALLBACK;
        }
        require(false, "invalid market sig");
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyGovernance {}

    function _implementation() internal view override returns (address) {
        return getRouterImplementation(msg.sig);
    }
}
