// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface ISwETH {
    function deposit() external payable;

    function depositWithReferral(address referral) external payable;

    function getRate() external view returns (uint256);
}
