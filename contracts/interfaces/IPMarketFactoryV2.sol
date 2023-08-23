// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IPMarketFactory.sol";

interface IPMarketFactoryV2 is IPMarketFactory {
    function rewardDistributor() external view returns (address);
}
