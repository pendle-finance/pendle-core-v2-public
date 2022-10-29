// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPBulkSellerFactory {
    event UpgradedBeacon(address indexed implementation);

    function get(address token, address SY) external view returns (address);

    function isMaintainer(address addr) external view returns (bool);

    function isAdmin(address addr) external view returns (bool);
}
