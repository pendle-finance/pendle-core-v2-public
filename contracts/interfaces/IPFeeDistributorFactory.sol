// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPFeeDistributorFactory {
    event UpgradedBeacon(address indexed implementation);

    function updateShares(address user, address pool) external;

    function getUserAndTotalSharesAt(
        address user,
        address pool,
        uint256 epoch
    ) external view returns (uint256 userShare, uint256 totalShare);

    function isAdmin(address addr) external view returns (bool);
}
