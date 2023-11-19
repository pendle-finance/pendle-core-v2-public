// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IThenaGaugeV2 {
    function emergency() external returns (bool);

    function depositAll() external;

    function withdrawAll() external;

    function emergencyWithdraw() external;

    function getReward() external;

    function balanceOf(address account) external view returns (uint256);
}
