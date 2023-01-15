// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

contract StorageLayout {
    address internal owner;
    address internal pendingOwner;

    mapping(bytes4 => address) internal selectorToFacet;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }
}
