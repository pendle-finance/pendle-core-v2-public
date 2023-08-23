pragma solidity ^0.8.0;

import "./IPAllAction.sol";

interface IPActionStorageStatic {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setDefaultApproxParams(ApproxParams memory params) external;

    function getDefaultApproxParams() external view returns (ApproxParams memory);

    function setBulkSellerFactory(address _bulkSellerFactory) external;

    function getBulkSellerFactory() external view returns (address);

    function getOwnerAndPendingOwner()
        external
        view
        returns (address _owner, address _pendingOwner);

    function transferOwnership(address newOwner, bool direct, bool renounce) external;

    function claimOwnership() external;
}
