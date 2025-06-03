// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IStandardizedYield.sol";

contract BalanceReader is UUPSUpgradeable, BoringOwnableUpgradeable {
    struct UserMarketInfo {
        uint256 lpBalance;
        uint256 lpActiveBalance;
        uint256[] lpRewardsOut;
        //
        uint256 ytBalance;
        uint256 ytInterestOut;
        uint256[] ytRewardsOut;
        //
        uint256 ptBalance;
    }

    struct UserSYInfo {
        uint256 syBalance;
        uint256[] rewardsOut;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    function getUserMarketInfos(address user, address[] memory markets) external returns (UserMarketInfo[] memory res) {
        res = new UserMarketInfo[](markets.length);

        for (uint256 i = 0; i < markets.length; ++i) {
            IPMarket market = IPMarket(markets[i]);

            UserMarketInfo memory info = res[i];
            (, IPPrincipalToken PT, IPYieldToken YT) = market.readTokens();

            info.lpBalance = market.balanceOf(user);
            info.lpActiveBalance = market.activeBalance(user);
            info.lpRewardsOut = market.redeemRewards(user);

            info.ytBalance = YT.balanceOf(user);
            (info.ytInterestOut, info.ytRewardsOut) = YT.redeemDueInterestAndRewards(user, true, true);

            info.ptBalance = PT.balanceOf(user);
        }
    }

    function getUserSYInfos(address user, address[] memory SYs) external returns (UserSYInfo[] memory res) {
        res = new UserSYInfo[](SYs.length);

        for (uint256 i = 0; i < SYs.length; ++i) {
            IStandardizedYield SY = IStandardizedYield(SYs[i]);

            UserSYInfo memory info = res[i];
            info.syBalance = SY.balanceOf(user);
            info.rewardsOut = SY.claimRewards(user);
        }
    }
}
