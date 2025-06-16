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
            info.lpRewardsOut = _redeemRewards(market, user);

            info.ytBalance = YT.balanceOf(user);
            (info.ytInterestOut, info.ytRewardsOut) = _redeemDueInterestAndRewards(YT, user);

            info.ptBalance = PT.balanceOf(user);
        }
    }

    function getUserSYInfos(address user, address[] memory SYs) external returns (UserSYInfo[] memory res) {
        res = new UserSYInfo[](SYs.length);

        for (uint256 i = 0; i < SYs.length; ++i) {
            IStandardizedYield SY = IStandardizedYield(SYs[i]);

            UserSYInfo memory info = res[i];
            info.syBalance = SY.balanceOf(user);
            info.rewardsOut = _claimRewards(SY, user);
        }
    }

    function _redeemRewards(IPMarket market, address user) internal returns (uint256[] memory /*rewardsOut*/) {
        try market.redeemRewards(user) returns (uint256[] memory rewardsOut) {
            return rewardsOut;
        } catch {
            return new uint256[](market.getRewardTokens().length);
        }
    }

    function _redeemDueInterestAndRewards(
        IPYieldToken YT,
        address user
    ) internal returns (uint256 /*interestOut*/, uint256[] memory /*rewardsOut*/) {
        try YT.redeemDueInterestAndRewards(user, true, true) returns (
            uint256 interestOut,
            uint256[] memory rewardsOut
        ) {
            return (interestOut, rewardsOut);
        } catch {
            return (0, new uint256[](YT.getRewardTokens().length));
        }
    }

    function _claimRewards(IStandardizedYield SY, address user) internal returns (uint256[] memory /*rewardsOut*/) {
        try SY.claimRewards(user) returns (uint256[] memory rewardsOut) {
            return rewardsOut;
        } catch {
            return new uint256[](SY.getRewardTokens().length);
        }
    }
}
