// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../PendleERC4626SY.sol";
import "../../../../interfaces/IPTokenWithSupplyCap.sol";

contract PendleMorphoMetaVaultSY is PendleERC4626SY, IPTokenWithSupplyCap {
    constructor(
        string memory _name,
        string memory _symbol,
        address _erc4626
    ) PendleERC4626SY(_name, _symbol, _erc4626) {}

    function getAbsoluteSupplyCap() external view returns (uint256) {
        return totalSupply() + IERC4626(yieldToken).maxMint(address(this));
    }

    function getAbsoluteTotalSupply() external view returns (uint256) {
        return totalSupply();
    }
}
