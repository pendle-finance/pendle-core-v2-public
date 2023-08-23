// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPBulkSellerFactory {
    event BulkSellerCreated(address indexed token, address indexed sy, address indexed bulk);

    event UpgradedBeacon(address indexed implementation);

    function get(address token, address SY) external view returns (address);

    function isMaintainer(address addr) external view returns (bool);
}
