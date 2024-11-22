// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../PendleERC4626SYV2.sol";
import "../../../../interfaces/IPTokenWithSupplyCap.sol";

contract PendleMorphoMetaVaultSY is PendleERC4626SYV2, IPTokenWithSupplyCap {
    constructor(
        string memory _name,
        string memory _symbol,
        address _erc4626
    ) PendleERC4626SYV2(_name, _symbol, _erc4626) {}

    function getAbsoluteSupplyCap() external view returns (uint256) {
        return IERC4626(yieldToken).totalSupply() + IERC4626(yieldToken).maxMint(address(this));
    }

    function getAbsoluteTotalSupply() external view returns (uint256) {
        return IERC4626(yieldToken).totalSupply();
    }
}
