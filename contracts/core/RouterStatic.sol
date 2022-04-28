// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../SuperComposableYield/ISuperComposableYield.sol";
import "../SuperComposableYield/implementations/IRewardManager.sol";
import "../interfaces/IPRouterStatic.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketFactory.sol";
import "../libraries/math/MarketMathAux.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RouterStatic is IPRouterStatic {
    using MarketMathCore for MarketState;
    using MarketMathAux for MarketState;
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;

    IPYieldContractFactory public immutable yieldContractFactory;
    IPMarketFactory public immutable marketFactory;

    constructor(IPYieldContractFactory _yieldContractFactory, IPMarketFactory _marketFactory) {
        yieldContractFactory = _yieldContractFactory;
        marketFactory = _marketFactory;
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
        )
    {
        MarketState memory state = IPMarket(market).readState(false);
        (, netLpOut, scyUsed, ptUsed) = state.addLiquidity(
            scyIndex(market),
            scyDesired,
            ptDesired,
            false
        );
    }

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netPtOut)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyOut, netPtOut) = state.removeLiquidity(lpToRemove, false);
    }

    function swapPtForScyStatic(address market, uint256 exactPtIn)
        external
        returns (uint256 netScyOut, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyOut, netScyFee) = state.swapExactPtForScy(
            scyIndex(market),
            exactPtIn,
            block.timestamp,
            false
        );
    }

    function swapScyForPtStatic(address market, uint256 exactPtOut)
        external
        returns (uint256 netScyIn, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyIn, netScyFee) = state.swapScyForExactPt(
            scyIndex(market),
            exactPtOut,
            block.timestamp,
            false
        );
    }

    function scyIndex(address market) public returns (SCYIndex index) {
        return SCYIndexLib.newIndex(IPMarket(market).SCY());
    }

    function getPtImpliedYield(address market) public view returns (int256) {
        MarketState memory state = IPMarket(market).readState(false);

        int256 lnImpliedRate = (state.lastLnImpliedRate).Int();
        return lnImpliedRate.exp();
    }

    function getPendleTokenType(address token)
        external
        view
        returns (
            bool isPT,
            bool isYT,
            bool isMarket
        )
    {
        if (yieldContractFactory.isPT(token)) isPT = true;
        else if (yieldContractFactory.isYT(token)) isYT = true;
        else if (marketFactory.isValidMarket(token)) isMarket = true;
    }

    function getUserPYInfo(address py, address user)
        public
        view
        returns (UserPYInfo memory userPYInfo)
    {
        (userPYInfo.yt, userPYInfo.pt) = getPY(py);
        IPYieldToken YT = IPYieldToken(userPYInfo.yt);
        userPYInfo.ytBalance = YT.balanceOf(user);
        userPYInfo.ptBalance = IPPrincipalToken(userPYInfo.pt).balanceOf(user);
        userPYInfo.unclaimedInterest.token = YT.SCY();
        (, userPYInfo.unclaimedInterest.amount) = YT.getInterestData(user);
        address[] memory rewardTokens = YT.getRewardTokens();
        TokenAmount[] memory unclaimedRewards = new TokenAmount[](rewardTokens.length);
        uint256 length = 0;
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            (, uint256 amount) = YT.getUserReward(user, rewardToken);
            if (amount > 0) {
                unclaimedRewards[length].token = rewardToken;
                unclaimedRewards[length].amount = amount;
                ++length;
            }
        }
        userPYInfo.unclaimedRewards = new TokenAmount[](length);
        for (uint256 i = 0; i < length; ++i) {
            userPYInfo.unclaimedRewards[i] = unclaimedRewards[i];
        }
    }

    function getPYInfo(address py)
        external
        returns (
            uint256 exchangeRate,
            uint256 totalSupply,
            RewardIndex[] memory rewardIndexes
        )
    {
        (address yt, ) = getPY(py);
        IPYieldToken YT = IPYieldToken(yt);
        (, exchangeRate) = YT.getScyIndex();
        totalSupply = YT.totalSupply();
        address[] memory rewardTokens = YT.getRewardTokens();
        rewardIndexes = new RewardIndex[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            rewardIndexes[i].rewardToken = rewardToken;
            (, rewardIndexes[i].index) = YT.getGlobalReward(rewardToken);
        }
    }

    function getPY(address py) public view returns (address pt, address yt) {
        if (yieldContractFactory.isYT(py)) {
            yt = py;
            pt = IPYieldToken(py).PT();
        } else {
            yt = IPPrincipalToken(py).YT();
            pt = py;
        }
    }

    function getMarketInfo(address market)
        external
        view
        returns (
            address pt,
            address scy,
            MarketState memory state,
            int256 impliedYield,
            uint256 exchangeRate
        )
    {
        IPMarket _market = IPMarket(market);
        pt = _market.PT();
        scy = _market.SCY();
        state = _market.readState(true);
        impliedYield = getPtImpliedYield(market);
        exchangeRate = 0; // TODO: get the actual exchange rate
    }

    function getUserMarketInfo(address market, address user)
        public
        view
        returns (UserMarketInfo memory userMarketInfo)
    {
        IPMarket _market = IPMarket(market);
        userMarketInfo.market = market;
        userMarketInfo.lpBalance = _market.balanceOf(user);
        // TODO: Is there a way to convert LP to PT and SCY?
        userMarketInfo.ptBalance = TokenAmount(_market.PT(), 0);
        userMarketInfo.scyBalance = TokenAmount(_market.SCY(), 0);
        // TODO: Get this from SCY once it is in the interface
        userMarketInfo.assetBalance = TokenAmount(address(0), 0);
    }

    function getUserPYPositionsByPYs(address user, address[] calldata pys)
        external
        view
        returns (UserPYInfo[] memory userPYPositions)
    {
        userPYPositions = new UserPYInfo[](pys.length);
        for (uint256 i = 0; i < pys.length; ++i) {
            userPYPositions[i] = getUserPYInfo(pys[i], user);
        }
    }

    function getUserMarketPositions(address user, address[] calldata markets)
        external
        view
        returns (UserMarketInfo[] memory userMarketPositions)
    {
        userMarketPositions = new UserMarketInfo[](markets.length);
        for (uint256 i = 0; i < markets.length; ++i) {
            userMarketPositions[i] = getUserMarketInfo(markets[i], user);
        }
    }

    function hasPYPosition(UserPYInfo memory userPYInfo) public pure returns (bool hasPosition) {
        hasPosition = (userPYInfo.ytBalance > 0 ||
            userPYInfo.ptBalance > 0 ||
            userPYInfo.unclaimedInterest.amount > 0 ||
            userPYInfo.unclaimedRewards.length > 0);
    }

    function getUserSCYInfo(address scy, address user)
        external
        view
        returns (uint256 balance, TokenAmount[] memory rewards)
    {
        ISuperComposableYield SCY = ISuperComposableYield(scy);
        balance = SCY.balanceOf(scy);
        address[] memory rewardTokens = SCY.getRewardTokens();
        rewards = new TokenAmount[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            rewards[i].token = rewardToken;
            (, rewards[i].amount) = IRewardManager(scy).getUserReward(user, rewardToken);
        }
    }
}
