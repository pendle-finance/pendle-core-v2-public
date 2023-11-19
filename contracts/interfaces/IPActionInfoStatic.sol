// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPActionInfoStatic {
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct UserSYInfo {
        TokenAmount syBalance;
        TokenAmount[] unclaimedRewards;
    }

    struct UserPYInfo {
        TokenAmount ptBalance;
        TokenAmount ytBalance;
        TokenAmount unclaimedInterest;
        TokenAmount[] unclaimedRewards;
    }

    struct UserMarketInfo {
        TokenAmount lpBalance;
        TokenAmount ptBalance;
        TokenAmount syBalance;
        TokenAmount[] unclaimedRewards;
    }

    function getPY(address py) external view returns (address pt, address yt);

    /// can be SY, PY or Market
    function getTokensInOut(
        address token
    ) external view returns (address[] memory tokensIn, address[] memory tokensOut);

    function getUserSYInfo(address sy, address user) external returns (UserSYInfo memory res);

    function getUserPYInfo(address py, address user) external returns (UserPYInfo memory res);

    function getUserMarketInfo(address market, address user) external returns (UserMarketInfo memory res);
}
