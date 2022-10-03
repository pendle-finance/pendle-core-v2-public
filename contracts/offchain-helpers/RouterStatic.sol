// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketFactory.sol";
import "../interfaces/IPVotingEscrowMainchain.sol";
import "../periphery/BoringOwnableUpgradeable.sol";
import "./MarketMathStatic.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../periphery/BoringOwnableUpgradeable.sol";
import "../libraries/math/WeekMath.sol";
import "../libraries/Errors.sol";

/// EXCLUDED FROM ALL AUDITS, TO BE CALLED ONLY BY PENDLE's SDK
contract RouterStatic is Initializable, BoringOwnableUpgradeable, UUPSUpgradeable {
    using Math for uint256;
    using VeBalanceLib for VeBalance;
    using VeBalanceLib for LockedPosition;

    uint128 public constant MAX_LOCK_TIME = 104 weeks;
    uint128 public constant MIN_LOCK_TIME = 1 weeks;

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

    IPYieldContractFactory internal immutable yieldContractFactory;
    IPMarketFactory internal immutable marketFactory;
    IPVotingEscrowMainchain internal immutable vePENDLE;

    constructor(
        IPYieldContractFactory _yieldContractFactory,
        IPMarketFactory _marketFactory,
        IPVotingEscrowMainchain _vePENDLE
    ) initializer {
        yieldContractFactory = _yieldContractFactory;
        marketFactory = _marketFactory;
        vePENDLE = _vePENDLE;
    }

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function getDefaultApproxParams() public pure returns (ApproxParams memory) {
        return
            ApproxParams({
                guessMin: 0,
                guessMax: type(uint256).max,
                guessOffchain: 0,
                maxIteration: 256,
                eps: 1e15
            });
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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
        if (yieldContractFactory.isPT(token)) isPT = true;
        else if (yieldContractFactory.isYT(token)) isYT = true;
        else if (marketFactory.isValidMarket(token)) isMarket = true;
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

    function getMarketInfo(address market)
        external
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
        state = _market.readState();
        impliedYield = getPtImpliedYield(market);
        exchangeRate = MarketMathStatic.getExchangeRate(market);
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

        MarketState memory state = _market.readState();
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

    // ============= MARKET ACTIONS =============

    function addLiquidityDualScyAndPtStatic(
        address market,
        uint256 netScyDesired,
        uint256 netPtDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netScyUsed,
            uint256 netPtUsed
        )
    {
        return
            MarketMathStatic.addLiquidityDualScyAndPtStatic(market, netScyDesired, netPtDesired);
    }

    function addLiquidityDualTokenAndPtStatic(
        address market,
        address tokenIn,
        uint256 netTokenDesired,
        uint256 netPtDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netTokenUsed,
            uint256 netPtUsed
        )
    {
        return
            MarketMathStatic.addLiquidityDualTokenAndPtStatic(
                market,
                tokenIn,
                netTokenDesired,
                netPtDesired
            );
    }

    function addLiquiditySinglePtStatic(address market, uint256 netPtIn)
        external
        returns (
            uint256 netLpOut,
            uint256 netPtToSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.addLiquiditySinglePtStatic(market, netPtIn, getDefaultApproxParams());
    }

    function addLiquiditySingleScyStatic(address market, uint256 netScyIn)
        public
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.addLiquiditySingleScyStatic(
                market,
                netScyIn,
                getDefaultApproxParams()
            );
    }

    function addLiquiditySingleBaseTokenStatic(
        address market,
        address baseToken,
        uint256 netBaseTokenIn
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.addLiquiditySingleBaseTokenStatic(
                market,
                baseToken,
                netBaseTokenIn,
                getDefaultApproxParams()
            );
    }

    function removeLiquidityDualScyAndPt(address market, uint256 netLpToRemove)
        external
        view
        returns (uint256 netScyOut, uint256 netPtOut)
    {
        return MarketMathStatic.removeLiquidityDualScyAndPtStatic(market, netLpToRemove);
    }

    function removeLiquidityDualTokenAndPtStatic(
        address market,
        uint256 netLpToRemove,
        address tokenOut
    ) external view returns (uint256 netTokenOut, uint256 netPtOut) {
        return
            MarketMathStatic.removeLiquidityDualTokenAndPtStatic(market, netLpToRemove, tokenOut);
    }

    function removeLiquiditySinglePtStatic(address market, uint256 netLpToRemove)
        external
        returns (
            uint256 netPtOut,
            uint256 netPtFromSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.removeLiquiditySinglePtStatic(
                market,
                netLpToRemove,
                getDefaultApproxParams()
            );
    }

    function removeLiquiditySingleScyStatic(address market, uint256 netLpToRemove)
        public
        returns (
            uint256 netScyOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.removeLiquiditySingleScyStatic(market, netLpToRemove);
    }

    function removeLiquiditySingleBaseTokenStatic(
        address market,
        uint256 netLpToRemove,
        address baseToken
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.removeLiquiditySingleBaseTokenStatic(
                market,
                netLpToRemove,
                baseToken
            );
    }

    function swapExactPtForScyStatic(address market, uint256 exactPtIn)
        public
        returns (
            uint256 netScyOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapExactPtForScyStatic(market, exactPtIn);
    }

    function swapScyForExactPtStatic(address market, uint256 exactPtOut)
        external
        returns (
            uint256 netScyIn,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapScyForExactPtStatic(market, exactPtOut);
    }

    function swapExactScyForPtStatic(address market, uint256 exactScyIn)
        public
        returns (
            uint256 netPtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapExactScyForPtStatic(market, exactScyIn, getDefaultApproxParams());
    }

    function swapPtForExactScyStatic(address market, uint256 exactScyOut)
        public
        returns (
            uint256 netPtIn,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapPtForExactScyStatic(
                market,
                exactScyOut,
                getDefaultApproxParams()
            );
    }

    function swapExactBaseTokenForPtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken
    )
        external
        returns (
            uint256 netPtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapExactBaseTokenForPtStatic(
                market,
                baseToken,
                amountBaseToken,
                getDefaultApproxParams()
            );
    }

    function swapExactPtForBaseTokenStatic(
        address market,
        uint256 exactPtIn,
        address baseToken
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapExactPtForBaseTokenStatic(market, exactPtIn, baseToken);
    }

    function swapScyForExactYtStatic(address market, uint256 exactYtOut)
        external
        returns (
            uint256 netScyIn,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapScyForExactYtStatic(market, exactYtOut);
    }

    function swapExactScyForYtStatic(address market, uint256 exactScyIn)
        public
        returns (
            uint256 netYtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapExactScyForYtStatic(market, exactScyIn, getDefaultApproxParams());
    }

    function swapExactYtForScyStatic(address market, uint256 exactYtIn)
        public
        returns (
            uint256 netScyOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapExactYtForScyStatic(market, exactYtIn);
    }

    function swapYtForExactScyStatic(address market, uint256 exactScyOut)
        external
        returns (
            uint256 netYtIn,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapYtForExactScyStatic(
                market,
                exactScyOut,
                getDefaultApproxParams()
            );
    }

    function swapExactYtForBaseTokenStatic(
        address market,
        uint256 exactYtIn,
        address baseToken
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapExactYtForBaseTokenStatic(market, exactYtIn, baseToken);
    }

    function swapExactBaseTokenForYtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken
    )
        external
        returns (
            uint256 netYtOut,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapExactBaseTokenForYtStatic(
                market,
                baseToken,
                amountBaseToken,
                getDefaultApproxParams()
            );
    }

    function swapExactPtForYtStatic(address market, uint256 exactPtIn)
        external
        returns (
            uint256 netYtOut,
            uint256 totalPtToSwap,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapExactPtForYt(market, exactPtIn, getDefaultApproxParams());
    }

    function swapExactYtForPtStatic(address market, uint256 exactYtIn)
        external
        returns (
            uint256 netPtOut,
            uint256 totalPtSwapped,
            uint256 netScyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapExactYtForPt(market, exactYtIn, getDefaultApproxParams());
    }

    // ============= vePENDLE =============

    function increaseLockPositionStatic(
        address user,
        uint128 additionalAmountToLock,
        uint128 newExpiry
    ) external view returns (uint128 newVeBalance) {
        if (!WeekMath.isValidWTime(newExpiry)) revert Errors.InvalidWTime(newExpiry);
        if (MiniHelpers.isTimeInThePast(newExpiry)) revert Errors.ExpiryInThePast(newExpiry);

        if (newExpiry > block.timestamp + MAX_LOCK_TIME) revert Errors.VEExceededMaxLockTime();
        if (newExpiry < block.timestamp + MIN_LOCK_TIME) revert Errors.VEInsufficientLockTime();

        LockedPosition memory oldPosition;

        {
            (uint128 amount, uint128 expiry) = vePENDLE.positionData(user);
            oldPosition = LockedPosition(amount, expiry);
        }

        if (newExpiry < oldPosition.expiry) revert Errors.VENotAllowedReduceExpiry();

        uint128 newTotalAmountLocked = additionalAmountToLock + oldPosition.amount;
        if (newTotalAmountLocked == 0) revert Errors.VEZeroAmountLocked();

        uint128 additionalDurationToLock = newExpiry - oldPosition.expiry;

        LockedPosition memory newPosition = LockedPosition(
            oldPosition.amount + additionalAmountToLock,
            oldPosition.expiry + additionalDurationToLock
        );

        VeBalance memory newBalance = newPosition.convertToVeBalance();
        return newBalance.getCurrentValue();
    }

    // ============= OTHER HELPERS =============

    function mintPYFromScyStatic(address YT, uint256 amountScyToMint)
        public
        returns (uint256 amountPY)
    {
        IPYieldToken _YT = IPYieldToken(YT);
        if (_YT.isExpired()) revert Errors.YCExpired();
        return amountScyToMint.mulDown(_YT.pyIndexCurrent());
    }

    function redeemPYToScyStatic(address YT, uint256 amountPYToRedeem)
        public
        returns (uint256 amountPY)
    {
        IPYieldToken _YT = IPYieldToken(YT);
        return amountPYToRedeem.divDown(_YT.pyIndexCurrent());
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

    function calcPriceImpact(address market, int256 netPtOut)
        public
        returns (uint256 priceImpact)
    {
        return MarketMathStatic.calcPriceImpact(market, netPtOut);
    }

    // either but not both pyToken or market must be != 0
    function getTokensInOut(address pyToken, address market)
        public
        view
        returns (address[] memory tokensIn, address[] memory tokensOut)
    {
        if (pyToken != address(0)) {
            // SCY interface is shared between pt & yt
            ISuperComposableYield SCY = ISuperComposableYield(IPPrincipalToken(pyToken).SCY());
            return (SCY.getTokensIn(), SCY.getTokensOut());
        } else {
            (ISuperComposableYield SCY, , ) = IPMarket(market).readTokens();
            return (SCY.getTokensIn(), SCY.getTokensOut());
        }
    }
}
