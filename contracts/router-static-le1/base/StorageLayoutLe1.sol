// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./MarketApproxLibLe1.sol";
import "../interfaces/IPBulkSellerFactory.sol";

abstract contract StorageLayoutLe1 {
    address internal owner;
    address internal pendingOwner;

    mapping(bytes4 => address) internal selectorToFacet;

    ApproxParams internal defaultApproxParams;

    IPBulkSellerFactory internal bulkSellerFactory;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}
