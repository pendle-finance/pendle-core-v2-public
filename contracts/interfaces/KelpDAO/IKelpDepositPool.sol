// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IKelpDepositPool {
    function lrtConfig() external view returns (address);

    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minRSETHAmountToReceive,
        string calldata referralId
    ) external;

    function getRsETHAmountToMint(address asset, uint256 amount) external view returns (uint256 rsethAmountToMint);

    function depositETH(uint256 minRSETHAmountExpected, string calldata referralId) external payable;
}
