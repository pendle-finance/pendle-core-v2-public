// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DiamondLib.sol";

contract BoringOwnableFacet {
    function owner() public view returns (address) {
        return DiamondLib.diamondStorage().contractOwner;
    }

    function pendingOwner() public view returns (address) {
        return DiamondLib.diamondStorage().pendingOwner;
    }

    /// @notice Transfers ownership to `newOwner`. Either directly or claimable by the new pending owner.
    /// Can only be invoked by the current `owner`.
    /// @param newOwner Address of the new owner.
    /// @param direct True if `newOwner` should be set immediately. False if `newOwner` needs to use `claimOwnership`.
    /// @param renounce Allows the `newOwner` to be `address(0)` if `direct` and `renounce` is True. Has no effect otherwise.
    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) public {
        DiamondLib.enforceIsContractOwner();

        DiamondLib.DiamondStorage storage ds = DiamondLib.diamondStorage();

        if (direct) {
            // Checks
            require(newOwner != address(0) || renounce, "Ownable: zero address");

            // Effects
            DiamondLib.setContractOwner(newOwner);
            ds.pendingOwner = address(0);
        } else {
            // Effects
            ds.pendingOwner = newOwner;
        }
    }

    /// @notice Needs to be called by `pendingOwner` to claim ownership.
    function claimOwnership() public {
        DiamondLib.DiamondStorage storage ds = DiamondLib.diamondStorage();

        address _pendingOwner = ds.pendingOwner;

        // Checks
        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        // Effects
        DiamondLib.setContractOwner(_pendingOwner);
        ds.pendingOwner = address(0);
    }
}
