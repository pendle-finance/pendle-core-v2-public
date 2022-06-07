// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../libraries/math/MarketMathCore.sol";

interface IPRouterStatic {
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct RewardIndex {
        address rewardToken;
        uint256 index;
    }

    struct UserPYInfo {
        address yt;
        address pt;
        uint256 ytBalance;
        uint256 ptBalance;
        TokenAmount unclaimedInterest;
        TokenAmount[] unclaimedRewards;
    }

    struct UserMarketInfo {
        address market;
        uint256 lpBalance;
        TokenAmount ptBalance;
        TokenAmount scyBalance;
        TokenAmount assetBalance;
    }

    function addLiquidityStatic(
        address market,
        uint256 scyDesired,
        uint256 ptDesired
    )
        external
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 ptUsed
        );

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netPtOut);

    function swapPtForScyStatic(address market, uint256 exactPtIn)
        external
        returns (uint256 netScyOut, uint256 netScyFee);

    function swapScyForPtStatic(address market, uint256 exactPtOut)
        external
        returns (uint256 netScyIn, uint256 netScyFee);

    function scyIndex(address market) external returns (SCYIndex index);

    function getPtImpliedYield(address market) external view returns (int256);

    function getPendleTokenType(address token)
        external
        view
        returns (
            bool isPT,
            bool isYT,
            bool isMarket
        );

    function getUserPYInfo(address py, address user)
        external
        view
        returns (UserPYInfo memory userPYInfo);

    function getPYInfo(address py)
        external
        returns (
            uint256 exchangeRate,
            uint256 totalSupply,
            RewardIndex[] memory rewardIndexes
        );

    function getPY(address py) external view returns (address yt, address pt);

    function getMarketInfo(address market)
        external
        view
        returns (
            address pt,
            address scy,
            MarketState memory state,
            int256 impliedYield,
            uint256 exchangeRate
        );

    function getUserMarketInfo(address market, address user)
        external
        view
        returns (UserMarketInfo memory userMarketInfo);

    function getUserPYPositionsByPYs(address user, address[] calldata pys)
        external
        view
        returns (UserPYInfo[] memory userPYPositions);

    function getUserMarketPositions(address user, address[] calldata markets)
        external
        view
        returns (UserMarketInfo[] memory userMarketPositions);

    function hasPYPosition(UserPYInfo memory userPYInfo) external pure returns (bool hasPosition);

    function getUserSCYInfo(address scy, address user)
        external
        view
        returns (uint256 balance, TokenAmount[] memory rewards);
}
