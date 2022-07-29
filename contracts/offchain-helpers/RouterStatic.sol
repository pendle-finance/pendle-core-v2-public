// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "../interfaces/ISuperComposableYield.sol";
import "../interfaces/IRewardManager.sol";
import "../interfaces/IPRouterStatic.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketFactory.sol";
import "../libraries/math/MarketApproxLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// EXCLUDED FROM ALL AUDITS, TO BE CALLED ONLY BY PENDLE's SDK
contract RouterStatic is IPRouterStatic {
    using MarketMathCore for MarketState;
    using MarketApproxLib for MarketState;
    using Math for uint256;
    using Math for int256;
    using LogExpMath for int256;
    using SCYIndexLib for SCYIndex;

    IPYieldContractFactory internal immutable yieldContractFactory;
    IPMarketFactory internal immutable marketFactory;
    ApproxParams internal approxParams =
        ApproxParams({
            guessMin: 0,
            guessMax: type(uint256).max,
            guessOffchain: 0,
            maxIteration: 256,
            eps: 1e15
        });

    constructor(IPYieldContractFactory _yieldContractFactory, IPMarketFactory _marketFactory) {
        yieldContractFactory = _yieldContractFactory;
        marketFactory = _marketFactory;
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
        exchangeRate = YT.scyIndexCurrent();
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
        if (yieldContractFactory.isPT(token)) isPT = true;
        else if (yieldContractFactory.isYT(token)) isYT = true;
        else if (marketFactory.isValidMarket(token)) isMarket = true;
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
        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = IPMarket(market).readTokens();

        pt = address(PT);
        scy = address(SCY);
        state = _market.readState(true);
        impliedYield = getPtImpliedYield(market);
        exchangeRate = getExchangeRate(market);
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
            (, rewards[i].amount) = IRewardManager(scy).userReward(rewardToken, user);
        }
    }

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
        )
    {
        MarketState memory state = IPMarket(market).readState(false);
        (, netLpOut, scyUsed, ptUsed) = state.addLiquidity(
            scyIndex(market),
            scyDesired,
            ptDesired,
            block.timestamp
        );
    }

    function addLiquiditySinglePtStatic(address market, uint256 netPtIn)
        external
        returns (uint256 netLpOut, uint256 netScyFee)
    {
        require(false, "NOT IMPLEMENTED");
    }

    function addLiquiditySingleScyStatic(address market, uint256 netScyIn)
        external
        returns (uint256 netLpOut, uint256 netScyFee)
    {
        require(false, "NOT IMPLEMENTED");
    }

    function addLiquiditySingleBaseTokenStatic(
        address market,
        address baseToken,
        uint256 netBaseTokenIn
    ) external returns (uint256 netLpOut, uint256 netScyFee) {
        require(false, "NOT IMPLEMENTED");
    }

    function removeLiquidityStatic(address market, uint256 lpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netPtOut)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyOut, netPtOut) = state.removeLiquidity(lpToRemove);
    }

    function removeLiquiditySinglePtStatic(address market, uint256 lpToRemove)
        external
        returns (uint256 netPtOut, uint256 netScyFee)
    {
        require(false, "NOT IMPLEMENTED");
    }

    function removeLiquiditySingleScyStatic(address market, uint256 lpToRemove)
        external
        returns (uint256 netScyOut, uint256 netScyFee)
    {
        require(false, "NOT IMPLEMENTED");
    }

    function removeLiquiditySingleBaseTokenStatic(
        address market,
        uint256 lpToRemove,
        address baseToken
    ) external returns (uint256 netBaseTokenOut, uint256 netScyFee) {
        require(false, "NOT IMPLEMENTED");
    }

    function swapExactPtForScyStatic(address market, uint256 exactPtIn)
        public
        view
        returns (uint256 netScyOut, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyOut, netScyFee) = state.swapExactPtForScy(
            scyIndex(market),
            exactPtIn,
            block.timestamp
        );
    }

    function swapScyForExactPtStatic(address market, uint256 exactPtOut)
        external
        view
        returns (uint256 netScyIn, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netScyIn, netScyFee) = state.swapScyForExactPt(
            scyIndex(market),
            exactPtOut,
            block.timestamp
        );
    }

    function swapExactScyForPtStatic(address market, uint256 exactScyIn)
        public
        view
        returns (uint256 netPtOut, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        (netPtOut, , netScyFee) = state.approxSwapExactScyForPt(
            scyIndex(market),
            exactScyIn,
            block.timestamp,
            approxParams
        );
    }

    function swapPtForExactScyStatic(address market, uint256 exactScyOut)
        public
        view
        returns (uint256 netPtIn, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);

        (netPtIn, , netScyFee) = state.approxSwapPtForExactScy(
            scyIndex(market),
            exactScyOut,
            block.timestamp,
            approxParams
        );
    }

    function swapExactBaseTokenForPtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken
    ) external view returns (uint256 netPtOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        return swapExactScyForPtStatic(market, SCY.previewDeposit(baseToken, amountBaseToken));
    }

    function swapExactPtForBaseTokenStatic(
        address market,
        uint256 exactYtIn,
        address baseToken
    ) external view returns (uint256 netBaseTokenOut, uint256 netScyFee) {
        uint256 netScyOut;
        (netScyOut, netScyFee) = swapExactPtForScyStatic(market, exactYtIn);

        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();
        netBaseTokenOut = SCY.previewRedeem(baseToken, netScyOut);
    }

    function swapScyForExactYtStatic(address market, uint256 exactYtOut)
        external
        view
        returns (uint256 netScyIn, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);

        SCYIndex index = scyIndex(market);

        uint256 scyReceived;
        (scyReceived, netScyFee) = state.swapExactPtForScy(
            scyIndex(market),
            exactYtOut,
            block.timestamp
        );

        uint256 totalScyNeed = index.assetToScyUp(exactYtOut);
        netScyIn = totalScyNeed.subMax0(scyReceived);
    }

    function swapExactScyForYtStatic(address market, uint256 exactScyIn)
        public
        view
        returns (uint256 netYtOut, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);
        SCYIndex index = scyIndex(market);

        (netYtOut, , netScyFee) = state.approxSwapExactScyForYt(
            index,
            exactScyIn,
            block.timestamp,
            approxParams
        );
    }

    function swapExactYtForScyStatic(address market, uint256 exactYtIn)
        public
        view
        returns (uint256 netScyOut, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);

        SCYIndex index = scyIndex(market);

        uint256 scyOwed;
        (scyOwed, netScyFee) = state.swapScyForExactPt(index, exactYtIn, block.timestamp);

        uint256 amountPYToRepayScyOwed = index.scyToAssetUp(scyOwed);
        uint256 amountPYToRedeemScyOut = exactYtIn - amountPYToRepayScyOwed;

        netScyOut = index.assetToScy(amountPYToRedeemScyOut);
    }

    function swapYtForExactScyStatic(address market, uint256 exactScyOut)
        external
        view
        returns (uint256 netYtIn, uint256 netScyFee)
    {
        MarketState memory state = IPMarket(market).readState(false);

        SCYIndex index = scyIndex(market);

        (netYtIn, , netScyFee) = state.approxSwapYtForExactScy(
            index,
            exactScyOut,
            block.timestamp,
            approxParams
        );
    }

    function swapExactYtForBaseTokenStatic(
        address market,
        uint256 exactYtIn,
        address baseToken
    ) external view returns (uint256 netBaseTokenOut, uint256 netScyFee) {
        uint256 netScyOut;
        (netScyOut, netScyFee) = swapExactYtForScyStatic(market, exactYtIn);

        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();
        netBaseTokenOut = SCY.previewRedeem(baseToken, netScyOut);
    }

    function swapExactBaseTokenForYtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken
    ) external view returns (uint256 netPtOut, uint256 netScyFee) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        return swapExactScyForYtStatic(market, SCY.previewDeposit(baseToken, amountBaseToken));
    }

    // ============= OTHER HELPERS =============

    function mintPYFromScyStatic(address YT, uint256 amountScyToMint)
        public
        returns (uint256 amountPY)
    {
        IPYieldToken _YT = IPYieldToken(YT);
        require(!_YT.isExpired(), "YT is expired");
        return amountScyToMint.mulDown(_YT.scyIndexCurrent());
    }

    function redeemPYToScyStatic(address YT, uint256 amountPYToRedeem)
        public
        returns (uint256 amountPY)
    {
        IPYieldToken _YT = IPYieldToken(YT);
        return amountPYToRedeem.divDown(_YT.scyIndexCurrent());
    }

    function mintPYFromBaseStatic(
        address YT,
        address baseToken,
        uint256 amountBaseToken
    ) external returns (uint256 amountPY) {
        ISuperComposableYield SCY = ISuperComposableYield(IPYieldToken(YT).SCY());
        return mintPYFromScyStatic(YT, SCY.previewDeposit(baseToken, amountBaseToken));
    }

    function redeemPYToBaseStatic(
        address YT,
        uint256 amountPYToRedeem,
        address baseToken
    ) external returns (uint256 amountBaseToken) {
        ISuperComposableYield SCY = ISuperComposableYield(IPYieldToken(YT).SCY());
        return SCY.previewRedeem(baseToken, redeemPYToScyStatic(YT, amountPYToRedeem));
    }

    function scyIndex(address market) public view returns (SCYIndex index) {
        (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();

        return SCYIndexLib.newIndex(SCY);
    }

    function getPY(address py) public view returns (address pt, address yt) {
        if (yieldContractFactory.isYT(py)) {
            pt = IPYieldToken(py).PT();
            yt = py;
        } else {
            pt = py;
            yt = IPPrincipalToken(py).YT();
        }
    }

    function getPtImpliedYield(address market) public view returns (int256) {
        MarketState memory state = IPMarket(market).readState(false);

        int256 lnImpliedRate = (state.lastLnImpliedRate).Int();
        return lnImpliedRate.exp();
    }

    function getExchangeRate(address market) public view returns (uint256) {
        MarketState memory state = IPMarket(market).readState(false);
        MarketPreCompute memory comp = state.getMarketPreCompute(
            scyIndex(market),
            block.timestamp
        );

        return
            MarketMathCore
                ._getExchangeRate(
                    state.totalPt,
                    comp.totalAsset,
                    comp.rateScalar,
                    comp.rateAnchor,
                    0
                )
                .Uint();
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
        userPYInfo.unclaimedInterest.token = YT.SCY();
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

        (ISuperComposableYield SCY, IPPrincipalToken PT, ) = _market.readTokens();
        (userMarketInfo.assetBalance.assetType, userMarketInfo.assetBalance.assetAddress, ) = SCY
            .assetInfo();

        MarketState memory state = _market.readState(false);
        uint256 totalLp = uint256(state.totalLp);

        if (totalLp == 0) {
            return userMarketInfo;
        }

        uint256 userPt = (userLp * uint256(state.totalPt)) / totalLp;
        uint256 userScy = (userLp * uint256(state.totalScy)) / totalLp;

        userMarketInfo.ptBalance = TokenAmount(address(PT), userPt);
        userMarketInfo.scyBalance = TokenAmount(address(SCY), userScy);
        userMarketInfo.assetBalance.amount = (userScy * SCY.exchangeRate()) / Math.ONE;
    }

    function hasPYPosition(UserPYInfo calldata userPYInfo) public pure returns (bool hasPosition) {
        hasPosition = (userPYInfo.ytBalance > 0 ||
            userPYInfo.ptBalance > 0 ||
            userPYInfo.unclaimedInterest.amount > 0 ||
            userPYInfo.unclaimedRewards.length > 0);
    }
}
