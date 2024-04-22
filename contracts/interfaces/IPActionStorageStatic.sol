// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../router/base/MarketApproxLib.sol";

interface IPActionStorageStatic {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setDefaultApproxParams(ApproxParams memory params) external;

    function getDefaultApproxParams() external view returns (ApproxParams memory);

    function getOwnerAndPendingOwner() external view returns (address _owner, address _pendingOwner);

    function transferOwnership(address newOwner, bool direct, bool renounce) external;

    function claimOwnership() external;
}
