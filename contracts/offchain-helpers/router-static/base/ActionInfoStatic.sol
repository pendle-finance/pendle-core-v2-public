// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../../../interfaces/IPMarket.sol";
import "../../../interfaces/IPRouterStatic.sol";
import "../../../interfaces/IPYieldContractFactory.sol";
import "../../../interfaces/IPMarketFactory.sol";

// solhint-disable no-empty-blocks
contract ActionInfoStatic is IPActionInfoStatic {
    function getPY(address py) public view returns (address pt, address yt) {
        try IPYieldToken(py).PT() returns (address _pt) {
            pt = _pt;
            yt = py;
        } catch {
            pt = py;
            yt = IPPrincipalToken(py).YT();
        }
    }

    /// can be SY, PY or Market
    function getTokensInOut(
        address token
    ) external view returns (address[] memory tokensIn, address[] memory tokensOut) {
        try IStandardizedYield(token).getTokensIn() returns (address[] memory res) {
            return (res, IStandardizedYield(token).getTokensOut());
        } catch {}

        try IPYieldToken(token).SY() returns (address SY) {
            return (IStandardizedYield(SY).getTokensIn(), IStandardizedYield(SY).getTokensOut());
        } catch {}

        try IPMarket(token).readTokens() returns (IStandardizedYield SY, IPPrincipalToken, IPYieldToken) {
            return (SY.getTokensIn(), SY.getTokensOut());
        } catch {}

        revert("invalid token");
    }

    function getUserSYInfo(address sy, address user) external returns (UserSYInfo memory res) {
        IStandardizedYield SY = IStandardizedYield(sy);

        // SY
        res.syBalance = TokenAmount(sy, _balanceOf(sy, user));

        // Rewards
        uint256[] memory rewardsOut = SY.claimRewards(user);
        address[] memory rewardTokens = SY.getRewardTokens();

        res.unclaimedRewards = _zipTokenAmounts(rewardTokens, rewardsOut);
    }

    function getUserPYInfo(address py, address user) external returns (UserPYInfo memory res) {
        (address _PT, address _YT) = getPY(py);
        IPYieldToken YT = IPYieldToken(_YT);

        // PT / YT
        res.ytBalance = TokenAmount(_YT, _balanceOf(_YT, user));
        res.ptBalance = TokenAmount(_PT, _balanceOf(_PT, user));

        // interest
        (uint256 interestOut, uint256[] memory rewardsOut) = YT.redeemDueInterestAndRewards(user, true, true);

        res.unclaimedInterest = TokenAmount(YT.SY(), interestOut);

        // Rewards
        address[] memory rewardTokens = YT.getRewardTokens();
        res.unclaimedRewards = _zipTokenAmounts(rewardTokens, rewardsOut);
    }

    function getUserMarketInfo(address market, address user) external returns (UserMarketInfo memory res) {
        IPMarket _market = IPMarket(market);
        MarketState memory state = _market.readState(address(this));

        if (uint256(state.totalLp) == 0) return res; // market not initialized

        // LP PT SY
        (IStandardizedYield SY, IPPrincipalToken PT, ) = _market.readTokens();

        uint256 userLp = _balanceOf(market, user);
        uint256 userPt = (userLp * uint256(state.totalPt)) / uint256(state.totalLp);
        uint256 userSy = (userLp * uint256(state.totalSy)) / uint256(state.totalLp);

        res.lpBalance = TokenAmount(market, userLp);
        res.ptBalance = TokenAmount(address(PT), userPt);
        res.syBalance = TokenAmount(address(SY), userSy);

        // Rewards
        uint256[] memory rewardsOut = _market.redeemRewards(user);
        address[] memory rewardTokens = _market.getRewardTokens();

        res.unclaimedRewards = _zipTokenAmounts(rewardTokens, rewardsOut);
    }

    function _zipTokenAmounts(
        address[] memory tokens,
        uint256[] memory amounts
    ) internal pure returns (TokenAmount[] memory res) {
        res = new TokenAmount[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            res[i] = TokenAmount(tokens[i], amounts[i]);
        }
    }

    function _balanceOf(address token, address user) internal view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }
}
