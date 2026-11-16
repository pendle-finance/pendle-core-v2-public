// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPReflector {
    function reflect(bytes calldata inputData) external returns (bytes memory result);
}
