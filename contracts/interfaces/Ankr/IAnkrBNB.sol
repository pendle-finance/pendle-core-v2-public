// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IAnkrBNB {
    function ratio() external view returns (uint256);

    function bondsToShares(uint256 amount) external view returns (uint256);

    function sharesToBonds(uint256 amount) external view returns (uint256);
}
