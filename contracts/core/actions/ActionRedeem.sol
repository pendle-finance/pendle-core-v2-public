// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../interfaces/IPActionRedeem.sol";
import "../../interfaces/ISuperComposableYield.sol";
import "../../interfaces/IPYieldToken.sol";
import "../../core/PendleMarket.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ActionRedeem is IPActionRedeem {
    function redeemDueIncome(
        address user,
        address[] calldata scys,
        address[] calldata yts,
        address[] calldata markets
    )
        external
        returns (
            uint256[][] memory scyRewards,
            uint256[] memory ytInterests,
            uint256[][] memory ytRewards,
            uint256[][] memory marketRewards
        )
    {
        scyRewards = new uint256[][](scys.length);
        for (uint256 i = 0; i < scys.length; ++i) {
            scyRewards[i] = ISuperComposableYield(scys[i]).claimRewards(user);
        }

        ytInterests = new uint256[](yts.length);
        ytRewards = new uint256[][](yts.length);
        for (uint256 i = 0; i < yts.length; ++i) {
            (ytInterests[i], ytRewards[i]) = IPYieldToken(yts[i]).redeemDueInterestAndRewards(
                user
            );
        }

        marketRewards = new uint256[][](markets.length);
        for (uint256 i = 0; i < markets.length; ++i) {
            marketRewards[i] = IPMarket(markets[i]).redeemRewards(user);
        }
    }
}
