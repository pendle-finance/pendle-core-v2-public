// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IKelpLRTConfig {
    function getSupportedAssetList() external view returns (address[] memory);

    function isSupportedAsset(address token) external view returns (bool);
}
