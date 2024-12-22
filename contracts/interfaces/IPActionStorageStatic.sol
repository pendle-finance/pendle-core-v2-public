// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../router/math/MarketApproxLibV2.sol";

import {IPAllEventsV3} from "./IPAllEventsV3.sol";

interface IPActionStorageStatic is IPAllEventsV3 {
    function setDefaultApproxParams(ApproxParams memory params) external;

    function getDefaultApproxParams() external view returns (ApproxParams memory);

    function getOwnerAndPendingOwner() external view returns (address _owner, address _pendingOwner);

    function transferOwnership(address newOwner, bool direct, bool renounce) external;

    function claimOwnership() external;
}
