// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../../interfaces/IPTokenWithSupplyCap.sol";
import "./PendleKarakVaultERC20SY.sol";

contract PendleKarakVaultUSDESY is PendleKarakVaultERC20SY, IPTokenWithSupplyCap {
    constructor(address _vault, address _vaultSupervisor) PendleKarakVaultERC20SY(_vault, _vaultSupervisor) {}

    function getAbsoluteSupplyCap() external view returns (uint256) {
        uint256 assetLimit = IKarakVault(vault).assetLimit();
        return IERC4626(vault).convertToShares(assetLimit);
    }

    function getAbsoluteTotalSupply() external view returns (uint256) {
        return IERC20(vault).totalSupply();
    }
}
