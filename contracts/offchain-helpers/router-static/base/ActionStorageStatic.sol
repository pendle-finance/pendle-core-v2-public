// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./StorageLayout.sol";
import "../../../interfaces/IPActionStorageStatic.sol";
import "../../../interfaces/IPMiniDiamond.sol";

contract ActionStorageStatic is StorageLayout, IPActionStorageStatic, IPMiniDiamond {
    function setDefaultApproxParams(ApproxParams memory params) external onlyOwner {
        defaultApproxParams = params;
    }

    function getDefaultApproxParams() external view returns (ApproxParams memory) {
        return defaultApproxParams;
    }

    function getOwnerAndPendingOwner() external view returns (address _owner, address _pendingOwner) {
        _owner = owner;
        _pendingOwner = pendingOwner;
    }

    function setFacetForSelectors(SelectorsToFacet[] calldata arr) external onlyOwner {
        for (uint256 i = 0; i < arr.length; ) {
            SelectorsToFacet memory s = arr[i];
            for (uint256 j = 0; j < s.selectors.length; ) {
                selectorToFacet[s.selectors[j]] = s.facet;
                unchecked {
                    j++;
                }
            }
            unchecked {
                i++;
            }
        }
    }

    function facetAddress(bytes4 selector) external view returns (address res) {
        res = selectorToFacet[selector];
        require(res != address(0), "selector not found");
    }

    // Ownable
    function transferOwnership(address newOwner, bool direct, bool renounce) external onlyOwner {
        if (direct) {
            require(newOwner != address(0) || renounce, "Ownable: zero address");

            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
            pendingOwner = address(0);
        } else {
            pendingOwner = newOwner;
        }
    }

    function claimOwnership() external {
        address _pendingOwner = pendingOwner;

        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        emit OwnershipTransferred(owner, _pendingOwner);
        owner = _pendingOwner;
        pendingOwner = address(0);
    }
}
