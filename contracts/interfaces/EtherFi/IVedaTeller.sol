// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

interface IVedaTeller {
    struct Asset {
        bool allowDeposits;
        bool allowWithdraws;
        uint16 sharePremium;
    }

    function deposit(
        address depositAsset,
        uint256 depositAmount,
        uint256 minimumMint
    ) external payable returns (uint256 share);

    function accountant() external view returns (address);

    function bulkDeposit(
        address depositAsset,
        uint256 depositAmount,
        uint256 minimumMint,
        address to
    ) external returns (uint256 shares);

    function assetData(address) external view returns (Asset memory);
}
