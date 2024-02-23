// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../PendleERC20SY.sol";

contract PendleUSDESY is PendleERC20SY {
    uint256 public supplyCap;

    event SupplyCapUpdated(uint256 newSupplyCap);

    error SupplyCapExceeded(uint256 totalSupply, uint256 supplyCap);

    constructor(address _usde, uint256 _initialSupplyCap) PendleERC20SY("SY Ethena USDE", "SY-USDE", _usde) {
        _updateSupplyCap(_initialSupplyCap);
    }

    function updateSupplyCap(uint256 newSupplyCap) public onlyOwner {
        _updateSupplyCap(newSupplyCap);
    }

    function _updateSupplyCap(uint256 newSupplyCap) internal {
        supplyCap = newSupplyCap;
        emit SupplyCapUpdated(newSupplyCap);
    }

    // @dev: whenNotPaused not needed as it has already been added to beforeTransfer
    function _afterTokenTransfer(address, address, uint256) internal virtual override {
        uint256 _supply = totalSupply();
        uint256 _supplyCap = supplyCap;
        if (_supply >= _supplyCap) {
            revert SupplyCapExceeded(_supply, _supplyCap);
        }
    }
}
