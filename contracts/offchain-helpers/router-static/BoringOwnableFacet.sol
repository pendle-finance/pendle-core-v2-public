// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./StorageLayout.sol";

abstract contract BoringOwnableFacet is StorageLayout {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function initialize() external {
        require(owner != address(0), "Ownable: already initialized");
        owner = msg.sender;
    }

    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) public onlyOwner {
        if (direct) {
            require(newOwner != address(0) || renounce, "Ownable: zero address");

            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
            pendingOwner = address(0);
        } else {
            pendingOwner = newOwner;
        }
    }

    function claimOwnership() public {
        address _pendingOwner = pendingOwner;

        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        emit OwnershipTransferred(owner, _pendingOwner);
        owner = _pendingOwner;
        pendingOwner = address(0);
    }
}
