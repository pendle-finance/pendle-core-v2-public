// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IPYieldContractFactory.sol";
import "../interfaces/IPMarketFactory.sol";
import "../interfaces/IPVotingEscrowMainchain.sol";
import "../interfaces/IPBulkSellerFactory.sol";
import "../interfaces/IPBulkSeller.sol";

import "./MarketMathStatic.sol";

import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../LiquidityMining/libraries/VeBalanceLib.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

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

    IPYieldContractFactory internal immutable yieldContractFactory;
    IPMarketFactory internal immutable marketFactory;
    IPVotingEscrowMainchain internal immutable vePENDLE;
    IPBulkSellerFactory internal immutable bulkFactory;

    constructor(
        IPYieldContractFactory _yieldContractFactory,
        IPMarketFactory _marketFactory,
        IPVotingEscrowMainchain _vePENDLE,
        IPBulkSellerFactory _bulkFactory
    ) initializer {
        yieldContractFactory = _yieldContractFactory;
        marketFactory = _marketFactory;
        vePENDLE = _vePENDLE;
        bulkFactory = _bulkFactory;
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
                eps: 1e14
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

    // ============= MARKET ACTIONS =============

    function addLiquidityDualSyAndPtStatic(
        address market,
        uint256 netSyDesired,
        uint256 netPtDesired
    )
        external
        view
        returns (
            uint256 netLpOut,
            uint256 netSyUsed,
            uint256 netPtUsed
        )
    {
        return MarketMathStatic.addLiquidityDualSyAndPtStatic(market, netSyDesired, netPtDesired);
    }

    function addLiquidityDualTokenAndPtStatic(
        address market,
        address tokenIn,
        uint256 netTokenDesired,
        address bulk,
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
        uint256 netSyDesired = previewDepositStatic(
            getSyMarket(market),
            tokenIn,
            netTokenDesired,
            bulk
        );

        uint256 netSyUsed;
        (netLpOut, netSyUsed, netPtUsed) = MarketMathStatic.addLiquidityDualSyAndPtStatic(
            market,
            netSyDesired,
            netPtDesired
        );

        if (netSyUsed != netSyDesired) revert Errors.RouterNotAllSyUsed(netSyDesired, netSyUsed);

        netTokenUsed = netTokenDesired;
    }

    function addLiquiditySinglePtStatic(address market, uint256 netPtIn)
        external
        returns (
            uint256 netLpOut,
            uint256 netPtToSwap,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.addLiquiditySinglePtStatic(market, netPtIn, getDefaultApproxParams());
    }

    function addLiquiditySingleSyStatic(address market, uint256 netSyIn)
        public
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.addLiquiditySingleSyStatic(market, netSyIn, getDefaultApproxParams());
    }

    function addLiquiditySingleBaseTokenStatic(
        address market,
        address baseToken,
        uint256 netBaseTokenIn,
        address bulk
    )
        external
        returns (
            uint256 netLpOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        uint256 netSyIn = previewDepositStatic(
            getSyMarket(market),
            baseToken,
            netBaseTokenIn,
            bulk
        );

        return
            MarketMathStatic.addLiquiditySingleSyStatic(market, netSyIn, getDefaultApproxParams());
    }

    function removeLiquidityDualSyAndPtStatic(address market, uint256 netLpToRemove)
        external
        view
        returns (uint256 netSyOut, uint256 netPtOut)
    {
        return MarketMathStatic.removeLiquidityDualSyAndPtStatic(market, netLpToRemove);
    }

    function removeLiquidityDualTokenAndPtStatic(
        address market,
        uint256 netLpToRemove,
        address tokenOut,
        address bulk
    ) external view returns (uint256 netTokenOut, uint256 netPtOut) {
        uint256 netSyOut;

        (netSyOut, netPtOut) = MarketMathStatic.removeLiquidityDualSyAndPtStatic(
            market,
            netLpToRemove
        );

        netTokenOut = previewRedeemStatic(getSyMarket(market), tokenOut, netSyOut, bulk);
    }

    function removeLiquiditySinglePtStatic(address market, uint256 netLpToRemove)
        external
        returns (
            uint256 netPtOut,
            uint256 netPtFromSwap,
            uint256 netSyFee,
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

    function removeLiquiditySingleSyStatic(address market, uint256 netLpToRemove)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.removeLiquiditySingleSyStatic(market, netLpToRemove);
    }

    function removeLiquiditySingleBaseTokenStatic(
        address market,
        uint256 netLpToRemove,
        address baseToken,
        address bulk
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        uint256 netSyOut;

        (netSyOut, netSyFee, priceImpact) = MarketMathStatic.removeLiquiditySingleSyStatic(
            market,
            netLpToRemove
        );

        netBaseTokenOut = previewRedeemStatic(getSyMarket(market), baseToken, netSyOut, bulk);
    }

    function swapExactPtForSyStatic(address market, uint256 exactPtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapExactPtForSyStatic(market, exactPtIn);
    }

    function swapSyForExactPtStatic(address market, uint256 exactPtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapSyForExactPtStatic(market, exactPtOut);
    }

    function swapExactSyForPtStatic(address market, uint256 exactSyIn)
        public
        returns (
            uint256 netPtOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapExactSyForPtStatic(market, exactSyIn, getDefaultApproxParams());
    }

    function swapPtForExactSyStatic(address market, uint256 exactSyOut)
        public
        returns (
            uint256 netPtIn,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapPtForExactSyStatic(market, exactSyOut, getDefaultApproxParams());
    }

    function swapExactBaseTokenForPtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken,
        address bulk
    )
        external
        returns (
            uint256 netPtOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        uint256 netSyIn = previewDepositStatic(
            getSyMarket(market),
            baseToken,
            amountBaseToken,
            bulk
        );
        return MarketMathStatic.swapExactSyForPtStatic(market, netSyIn, getDefaultApproxParams());
    }

    function swapExactPtForBaseTokenStatic(
        address market,
        uint256 exactPtIn,
        address baseToken,
        address bulk
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        uint256 netSyOut;
        (netSyOut, netSyFee, priceImpact) = MarketMathStatic.swapExactPtForSyStatic(
            market,
            exactPtIn
        );

        netBaseTokenOut = previewRedeemStatic(getSyMarket(market), baseToken, netSyOut, bulk);
    }

    function swapSyForExactYtStatic(address market, uint256 exactYtOut)
        external
        returns (
            uint256 netSyIn,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapSyForExactYtStatic(market, exactYtOut);
    }

    function swapExactSyForYtStatic(address market, uint256 exactSyIn)
        public
        returns (
            uint256 netYtOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapExactSyForYtStatic(market, exactSyIn, getDefaultApproxParams());
    }

    function swapExactYtForSyStatic(address market, uint256 exactYtIn)
        public
        returns (
            uint256 netSyOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return MarketMathStatic.swapExactYtForSyStatic(market, exactYtIn);
    }

    function swapYtForExactSyStatic(address market, uint256 exactSyOut)
        external
        returns (
            uint256 netYtIn,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        return
            MarketMathStatic.swapYtForExactSyStatic(market, exactSyOut, getDefaultApproxParams());
    }

    function swapExactYtForBaseTokenStatic(
        address market,
        uint256 exactYtIn,
        address baseToken,
        address bulk
    )
        external
        returns (
            uint256 netBaseTokenOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        uint256 netSyOut;
        (netSyOut, netSyFee, priceImpact) = MarketMathStatic.swapExactYtForSyStatic(
            market,
            exactYtIn
        );

        netBaseTokenOut = previewRedeemStatic(getSyMarket(market), baseToken, netSyOut, bulk);
    }

    function swapExactBaseTokenForYtStatic(
        address market,
        address baseToken,
        uint256 amountBaseToken,
        address bulk
    )
        external
        returns (
            uint256 netYtOut,
            uint256 netSyFee,
            uint256 priceImpact
        )
    {
        uint256 netSyIn = previewDepositStatic(
            getSyMarket(market),
            baseToken,
            amountBaseToken,
            bulk
        );

        return MarketMathStatic.swapExactSyForYtStatic(market, netSyIn, getDefaultApproxParams());
    }

    function swapExactPtForYtStatic(address market, uint256 exactPtIn)
        external
        returns (
            uint256 netYtOut,
            uint256 totalPtToSwap,
            uint256 netSyFee,
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
            uint256 netSyFee,
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

    function mintPYFromSyStatic(address YT, uint256 amountSyToMint)
        public
        returns (uint256 amountPY)
    {
        IPYieldToken _YT = IPYieldToken(YT);
        if (_YT.isExpired()) revert Errors.YCExpired();
        return amountSyToMint.mulDown(_YT.pyIndexCurrent());
    }

    function redeemPYToSyStatic(address YT, uint256 amountPYToRedeem)
        public
        returns (uint256 amountPY)
    {
        IPYieldToken _YT = IPYieldToken(YT);
        return amountPYToRedeem.divDown(_YT.pyIndexCurrent());
    }

    function mintPYFromBaseStatic(
        address YT,
        address baseToken,
        uint256 amountBaseToken,
        address bulk
    ) external returns (uint256 amountPY) {
        IStandardizedYield SY = IStandardizedYield(IPYieldToken(YT).SY());
        uint256 amountSy = previewDepositStatic(SY, baseToken, amountBaseToken, bulk);
        return mintPYFromSyStatic(YT, amountSy);
    }

    function redeemPYToBaseStatic(
        address YT,
        uint256 amountPYToRedeem,
        address baseToken,
        address bulk
    ) external returns (uint256 amountBaseToken) {
        IStandardizedYield SY = IStandardizedYield(IPYieldToken(YT).SY());
        uint256 amountSy = redeemPYToSyStatic(YT, amountPYToRedeem);
        return previewRedeemStatic(SY, baseToken, amountSy, bulk);
    }

    function previewDepositStatic(
        IStandardizedYield SY,
        address baseToken,
        uint256 amountToken,
        address bulk
    ) public view returns (uint256 amountSy) {
        if (bulk != address(0)) {
            return IPBulkSeller(bulk).calcSwapExactTokenForSy(amountToken);
        } else {
            return SY.previewDeposit(baseToken, amountToken);
        }
    }

    function previewRedeemStatic(
        IStandardizedYield SY,
        address baseToken,
        uint256 amountSy,
        address bulk
    ) public view returns (uint256 amountBaseToken) {
        if (bulk != address(0)) {
            return IPBulkSeller(bulk).calcSwapExactSyForToken(amountSy);
        } else {
            return SY.previewRedeem(baseToken, amountSy);
        }
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
            // SY interface is shared between pt & yt
            IStandardizedYield SY = IStandardizedYield(IPPrincipalToken(pyToken).SY());
            return (SY.getTokensIn(), SY.getTokensOut());
        } else {
            (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
            return (SY.getTokensIn(), SY.getTokensOut());
        }
    }

    function getAmountTokenToMintSy(
        IStandardizedYield SY,
        address tokenIn,
        address bulk,
        uint256 netSyOut
    ) public view returns (uint256 netTokenIn) {
        uint256 pivotAmount = netSyOut;

        uint256 low = pivotAmount;
        {
            while (true) {
                uint256 lowSyOut = previewDepositStatic(SY, tokenIn, low, bulk);
                if (lowSyOut >= netSyOut) low /= 10;
                else break;
            }
        }

        uint256 high = pivotAmount;
        {
            while (true) {
                uint256 highSyOut = previewDepositStatic(SY, tokenIn, high, bulk);
                if (highSyOut < netSyOut) high *= 10;
                else break;
            }
        }

        while (low <= high) {
            uint256 mid = (low + high) / 2;
            uint256 syOut = previewDepositStatic(SY, tokenIn, mid, bulk);

            if (syOut >= netSyOut) {
                netTokenIn = mid;
                high = mid - 1;
            } else {
                low = mid + 1;
            }
        }

        assert(netTokenIn > 0);
    }

    function getSyMarket(address market) public view returns (IStandardizedYield) {
        (IStandardizedYield SY, , ) = IPMarket(market).readTokens();
        return SY;
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
        bulk = IPBulkSellerFactory(bulkFactory).get(token, SY);
        if (bulk != address(0)) {
            BulkSellerState memory state = IPBulkSeller(bulk).readState();
            totalToken = state.totalToken;
            totalSy = state.totalSy;
        }
    }
}
