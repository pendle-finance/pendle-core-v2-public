// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IBoringOwnableUpgradeable {
    function transferOwnership(
        address newOwner,
        bool direct,
        bool renounce
    ) external;
}
