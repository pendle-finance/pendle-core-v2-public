// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../router/base/MarketApproxLib.sol";

abstract contract StorageLayout {
    address internal owner;
    address internal pendingOwner;

    mapping(bytes4 => address) internal selectorToFacet;

    ApproxParams internal defaultApproxParams;

    address internal _deprecated_bulkSellerFactory;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}
