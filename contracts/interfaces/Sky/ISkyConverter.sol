// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ISkyConverter {
    function daiToUsds(address usr, uint256 wad) external;

    function usdsToDai(address usr, uint256 wad) external;
}
