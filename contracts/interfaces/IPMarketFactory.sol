// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

interface IPMarketFactory {
    function isValidMarket(address market) external view returns (bool);

    function treasury() external view returns (address);
}
