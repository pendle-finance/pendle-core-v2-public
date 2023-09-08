// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IHMXCalculator {
    function getAUME30(bool _isMaxPrice) external view returns (uint256);
}