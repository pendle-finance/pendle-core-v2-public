// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGMXPriceHelper {
    function getPrice(address gm) external view returns (uint256);
}
