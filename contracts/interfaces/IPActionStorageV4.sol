// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IPAllEventsV3} from "./IPAllEventsV3.sol";

interface IPActionStorageV4 is IPAllEventsV3 {
    struct SelectorsToFacet {
        address facet;
        bytes4[] selectors;
    }

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function transferOwnership(address newOwner, bool direct, bool renounce) external;

    function claimOwnership() external;

    function setSelectorToFacets(SelectorsToFacet[] calldata arr) external;

    function selectorToFacet(bytes4 selector) external view returns (address);
}
