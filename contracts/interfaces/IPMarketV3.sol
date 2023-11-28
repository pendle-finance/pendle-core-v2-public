// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPMarket.sol";

interface IPMarketV3 is IPMarket {
    function getNonOverrideLnFeeRateRoot() external view returns (uint80);
}
