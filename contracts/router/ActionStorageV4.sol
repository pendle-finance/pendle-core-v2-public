// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../interfaces/IPActionStorageV4.sol";
import "./RouterStorage.sol";

contract ActionStorageV4 is RouterStorage, IPActionStorageV4 {
    modifier onlyOwner() {
        require(msg.sender == owner(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _getCoreStorage().owner;
    }

    function pendingOwner() public view returns (address) {
        return _getCoreStorage().pendingOwner;
    }

    function setSelectorToFacets(SelectorsToFacet[] calldata arr) external onlyOwner {
        CoreStorage storage $ = _getCoreStorage();

        for (uint256 i = 0; i < arr.length; i++) {
            SelectorsToFacet memory s = arr[i];
            for (uint256 j = 0; j < s.selectors.length; j++) {
                $.selectorToFacet[s.selectors[j]] = s.facet;
                emit SelectorToFacetSet(s.selectors[j], s.facet);
            }
        }
    }

    function selectorToFacet(bytes4 selector) external view returns (address) {
        CoreStorage storage $ = _getCoreStorage();
        return $.selectorToFacet[selector];
    }

    // Ownable
    function transferOwnership(address newOwner, bool direct, bool renounce) external onlyOwner {
        CoreStorage storage $ = _getCoreStorage();

        if (direct) {
            require(newOwner != address(0) || renounce, "Ownable: zero address");

            emit OwnershipTransferred($.owner, newOwner);
            $.owner = newOwner;
            $.pendingOwner = address(0);
        } else {
            $.pendingOwner = newOwner;
        }
    }

    function claimOwnership() external {
        CoreStorage storage $ = _getCoreStorage();

        address _pendingOwner = $.pendingOwner;

        require(msg.sender == _pendingOwner, "Ownable: caller != pending owner");

        emit OwnershipTransferred($.owner, _pendingOwner);
        $.owner = _pendingOwner;
        $.pendingOwner = address(0);
    }
}
