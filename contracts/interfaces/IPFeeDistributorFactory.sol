// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPFeeDistributorFactory {
    event UpgradedBeacon(address indexed implementation);
    
    function isAdmin(address addr) external view returns (bool);
}
