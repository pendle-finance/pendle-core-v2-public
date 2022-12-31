// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../MarketMathStatic.sol";

import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPYieldContractFactory.sol";
import "../../interfaces/IPMarketFactory.sol";
import "../../interfaces/IPBulkSellerFactory.sol";
import "../../interfaces/IPBulkSeller.sol";

contract StaticMarketInfoFacet {
    using Math for uint256;

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct AssetAmount {
        IStandardizedYield.AssetType assetType;
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
        TokenAmount syBalance;
        AssetAmount assetBalance;
    }

    // to initialize
    struct StaticMarketInfoFacetStorage {
        IPYieldContractFactory yieldContractFactory;
        IPMarketFactory marketFactory;
        IPBulkSellerFactory bulkFactory;
    }

    function getStaticMarketInfoFacetStorage()
        internal
        pure
        returns (StaticMarketInfoFacetStorage storage storageStruct)
    {
        bytes32 position = keccak256("static.market.info.facet.storage");
        assembly {
            storageStruct.slot := position
        }
    }

    // ============= SYSTEM INFO =============

    function getPYInfo(address py)
        external
        returns (
            uint256 exchangeRate,
            uint256 totalSupply,
            RewardIndex[] memory rewardIndexes
        )
    {
        (, address yt) = getPY(py);
        IPYieldToken YT = IPYieldToken(yt);
        exchangeRate = YT.pyIndexCurrent();
        totalSupply = YT.totalSupply();
        address[] memory rewardTokens = YT.getRewardTokens();
        rewardIndexes = new RewardIndex[](rewardTokens.length);

        uint256[] memory indexes = YT.rewardIndexesCurrent();
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            rewardIndexes[i].rewardToken = rewardToken;
            rewardIndexes[i].index = indexes[i];
        }
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
        if (getStaticMarketInfoFacetStorage().yieldContractFactory.isPT(token)) isPT = true;
        else if (getStaticMarketInfoFacetStorage().yieldContractFactory.isYT(token)) isYT = true;
        else if (getStaticMarketInfoFacetStorage().marketFactory.isValidMarket(token)) isMarket = true;
    }

    function getPY(address py) public view returns (address pt, address yt) {
        if (getStaticMarketInfoFacetStorage().yieldContractFactory.isYT(py)) {
            pt = IPYieldToken(py).PT();
            yt = py;
        } else {
            pt = py;
            yt = IPPrincipalToken(py).YT();
        }
    }

    function getMarketInfo(address market)
        external
        returns (
            address pt,
            address sy,
            MarketState memory state,
            int256 impliedYield,
            uint256 exchangeRate
        )
    {
        IPMarket _market = IPMarket(market);
        (IStandardizedYield SY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        pt = address(PT);
        sy = address(SY);
        state = _market.readState(address(this));
        impliedYield = getPtImpliedYield(market);
        exchangeRate = getTradeExchangeRateExcludeFee(market);
    }   

    // either but not both pyToken or market must be != 0
    function getTokensInOut(address pyToken, address market)
        public
        view
        returns (address[] memory tokensIn, address[] memory tokensOut)
    {
        if (pyToken != address(0)) {
            // SY interface is shared between pt & yt
            IStandardizedYield SY = IStandardizedYield(IPPrincipalToken(pyToken).SY());
            return (SY.getTokensIn(), SY.getTokensOut());
        } else {
            (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
            return (SY.getTokensIn(), SY.getTokensOut());
        }
    }

    // ============= USER INFO =============

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

    function getUserSYInfo(address sy, address user)
        external
        view
        returns (uint256 balance, TokenAmount[] memory rewards)
    {
        IStandardizedYield SY = IStandardizedYield(sy);
        balance = SY.balanceOf(sy);
        address[] memory rewardTokens = SY.getRewardTokens();
        rewards = new TokenAmount[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            rewards[i].token = rewardToken;
            (, rewards[i].amount) = IRewardManager(sy).userReward(rewardToken, user);
        }
    }

    function getUserPYInfo(address py, address user)
        public
        view
        returns (UserPYInfo memory userPYInfo)
    {
        (userPYInfo.pt, userPYInfo.yt) = getPY(py);
        IPYieldToken YT = IPYieldToken(userPYInfo.yt);
        userPYInfo.ytBalance = YT.balanceOf(user);
        userPYInfo.ptBalance = IPPrincipalToken(userPYInfo.pt).balanceOf(user);
        userPYInfo.unclaimedInterest.token = YT.SY();
        (, userPYInfo.unclaimedInterest.amount) = YT.userInterest(user);
        address[] memory rewardTokens = YT.getRewardTokens();
        TokenAmount[] memory unclaimedRewards = new TokenAmount[](rewardTokens.length);
        uint256 length = 0;
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address rewardToken = rewardTokens[i];
            (, uint256 amount) = YT.userReward(rewardToken, user);
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

    function getUserMarketInfo(address market, address user)
        public
        view
        returns (UserMarketInfo memory userMarketInfo)
    {
        IPMarket _market = IPMarket(market);
        uint256 userLp = _market.balanceOf(user);

        userMarketInfo.market = market;
        userMarketInfo.lpBalance = userLp;

        (IStandardizedYield SY, IPPrincipalToken PT, ) = _market.readTokens();
        (userMarketInfo.assetBalance.assetType, userMarketInfo.assetBalance.assetAddress, ) = SY
            .assetInfo();

        MarketState memory state = _market.readState(address(this));
        uint256 totalLp = uint256(state.totalLp);

        if (totalLp == 0) {
            return userMarketInfo;
        }

        uint256 userPt = (userLp * uint256(state.totalPt)) / totalLp;
        uint256 userSy = (userLp * uint256(state.totalSy)) / totalLp;

        userMarketInfo.ptBalance = TokenAmount(address(PT), userPt);
        userMarketInfo.syBalance = TokenAmount(address(SY), userSy);
        userMarketInfo.assetBalance.amount = (userSy * SY.exchangeRate()) / Math.ONE;
    }

    function hasPYPosition(UserPYInfo calldata userPYInfo) public pure returns (bool hasPosition) {
        hasPosition = (userPYInfo.ytBalance > 0 ||
            userPYInfo.ptBalance > 0 ||
            userPYInfo.unclaimedInterest.amount > 0 ||
            userPYInfo.unclaimedRewards.length > 0);
    }

    function getBulkSellerInfo(address token, address SY)
        external
        view
        returns (
            address bulk,
            uint256 totalToken,
            uint256 totalSy
        )
    {
        bulk = IPBulkSellerFactory(getStaticMarketInfoFacetStorage().bulkFactory).get(token, SY);
        if (bulk != address(0)) {
            BulkSellerState memory state = IPBulkSeller(bulk).readState();
            if (state.rateTokenToSy != 0 || state.rateSyToToken != 0) {
                totalToken = state.totalToken;
                totalSy = state.totalSy;
            }
        }
    }

    function getBulkSellerInfo(
        address token,
        address SY,
        uint256 netTokenIn,
        uint256 netSyIn
    )
        external
        view
        returns (
            address bulk,
            uint256 totalToken,
            uint256 totalSy
        )
    {
        bulk = IPBulkSellerFactory(getStaticMarketInfoFacetStorage().bulkFactory).get(token, SY);
        if (bulk != address(0)) {
            BulkSellerState memory state = IPBulkSeller(bulk).readState();

            // Paused check
            if (state.rateTokenToSy == 0 || state.rateSyToToken == 0) {
                return (address(0), 0, 0);
            }

            // Liquidity check
            uint256 postFeeRateTokenToSy = state.rateTokenToSy.mulDown(Math.ONE - state.feeRate);
            uint256 postFeeRateSyToToken = state.rateSyToToken.mulDown(Math.ONE - state.feeRate);
            if (
                netTokenIn.mulDown(postFeeRateTokenToSy) > state.totalSy ||
                netSyIn.mulDown(postFeeRateSyToToken) > state.totalToken
            ) {
                return (address(0), 0, 0);
            }

            // return...
            totalToken = state.totalToken;
            totalSy = state.totalSy;
        }
    }

    // ============= MATH HELPERS =============

    function getDefaultApproxParams() public pure returns (ApproxParams memory) {
        return MarketMathStatic.getDefaultApproxParams();
    }

    function getPtImpliedYield(address market) public view returns (int256) {
        return MarketMathStatic.getPtImpliedYield(market);
    }

    function pyIndex(address market) public returns (PYIndex index) {
        return MarketMathStatic.pyIndex(market);
    }

    function getExchangeRate(address market) public returns (uint256) {
        return getTradeExchangeRateIncludeFee(market, 0);
    }

    function getTradeExchangeRateIncludeFee(address market, int256 netPtOut)
        public
        returns (uint256)
    {
        return MarketMathStatic.getTradeExchangeRateIncludeFee(market, netPtOut);
    }

    function getTradeExchangeRateExcludeFee(address market)
        public
        returns (uint256)
    {
        return MarketMathStatic.getTradeExchangeRateExcludeFee(market);
    }

    function calcPriceImpact(address market, int256 netPtOut)
        public
        returns (uint256 priceImpact)
    {
        return MarketMathStatic.calcPriceImpactPt(market, netPtOut);
    }
}
