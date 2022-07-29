// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "./ISuperComposableYield.sol";
import "../libraries/math/MarketMathCore.sol";

interface IPRouterStatic {
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct AssetAmount {
        ISuperComposableYield.AssetType assetType;
        address assetAddress;
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
        AssetAmount assetBalance;
    }

    // ============= SYSTEM INFO =============

    function getPYInfo(address py)
        external
        returns (
            uint256 exchangeRate,
            uint256 totalSupply,
            RewardIndex[] memory rewardIndexes
        );

    function getPendleTokenType(address token)
        external
        view
        returns (
            bool isPT,
            bool isYT,
            bool isMarket
        );

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

    // ============= USER INFO =============

    function getUserPYPositionsByPYs(address user, address[] calldata pys)
        external
        view
        returns (UserPYInfo[] memory userPYPositions);

    function getUserMarketPositions(address user, address[] calldata markets)
        external
        view
        returns (UserMarketInfo[] memory userMarketPositions);

    function getUserSCYInfo(address scy, address user)
        external
        view
        returns (uint256 balance, TokenAmount[] memory rewards);

    // ============= MARKET ACTIONS =============

    function addLiquidityStatic(
        address market,
        uint256 scyDesired,
        uint256 ptDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 scyUsed,
            uint256 ptUsed
        );

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netPtOut);

    function swapExactPtForScyStatic(address market, uint256 exactPtIn)
        external
        view
        returns (
            uint256 netScyOut,
            uint256 netScyFee,
            uint256 priceImpact
        );

    function swapScyForExactPtStatic(address market, uint256 exactPtOut)
        external
        view
        returns (
            uint256 netScyIn,
            uint256 netScyFee,
            uint256 priceImpact
        );

    function swapExactScyForPtStatic(address market, uint256 exactScyIn)
        external
        view
        returns (
            uint256 netPtOut,
            uint256 netScyFee,
            uint256 priceImpact
        );

    // ============= OTHER HELPERS =============

    function scyIndex(address market) external view returns (SCYIndex index);

    function getPY(address py) external view returns (address pt, address yt);

    function getPtImpliedYield(address market) external view returns (int256);

    function getUserPYInfo(address py, address user)
        external
        view
        returns (UserPYInfo memory userPYInfo);

    function getUserMarketInfo(address market, address user)
        external
        view
        returns (UserMarketInfo memory userMarketInfo);

    function hasPYPosition(UserPYInfo calldata userPYInfo)
        external
        pure
        returns (bool hasPosition);
}
