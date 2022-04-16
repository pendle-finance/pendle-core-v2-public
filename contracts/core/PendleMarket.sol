// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "./PendleBaseToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../SuperComposableYield/ISuperComposableYield.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPMarketFactory.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../interfaces/IPMarketAddRemoveCallback.sol";

import "../libraries/math/LogExpMath.sol";
import "../libraries/math/FixedPoint.sol";
import "../libraries/math/MarketMathUint.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// solhint-disable reason-string
contract PendleMarket is PendleBaseToken, IPMarket, ReentrancyGuard {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using FixedPoint for uint128;
    using LogExpMath for uint256;
    using MarketMathUint for MarketAllParams;
    using MarketMathCore for MarketAllParams;
    using SafeERC20 for IERC20;

    string private constant NAME = "Pendle Market";
    string private constant SYMBOL = "PENDLE-LPT";

    address public immutable OT;
    address public immutable SCY;
    address public immutable YT;

    int256 public immutable scalarRoot;
    uint256 public immutable feeRateRoot; // allow fee to be changable?
    int256 public immutable initialAnchor;

    uint256 public immutable rateOracleTimeWindow;
    int8 public immutable reserveFeePercent;

    MarketStorage public marketStorage;

    constructor(
        address _OT,
        uint256 _rateOracleTimeWindow,
        uint256 _feeRateRoot,
        int256 _scalarRoot,
        int256 _initialAnchor,
        uint8 _reserveFeePercent
    ) PendleBaseToken(NAME, SYMBOL, 18, IPOwnershipToken(_OT).expiry()) {
        OT = _OT;
        SCY = IPOwnershipToken(_OT).SCY();
        YT = IPOwnershipToken(_OT).YT();
        feeRateRoot = _feeRateRoot;
        scalarRoot = _scalarRoot;
        rateOracleTimeWindow = _rateOracleTimeWindow;

        require(_reserveFeePercent <= 100, "invalid fee rate");
        reserveFeePercent = int8(_reserveFeePercent);
        initialAnchor = _initialAnchor;
    }

    function addLiquidity(
        address receiver,
        uint256 scyDesired,
        uint256 otDesired,
        bytes calldata data
    )
        external
        nonReentrant
        returns (
            uint256 lpToAccount,
            uint256 scyUsed,
            uint256 otUsed
        )
    {
        MarketAllParams memory market = readState();
        SCYIndex index = SCYIndexLib.newIndex(SCY);

        uint256 lpToReserve;
        (lpToReserve, lpToAccount, scyUsed, otUsed) = market.addLiquidity(
            index,
            scyDesired,
            otDesired
        );

        // initializing the market
        if (lpToReserve != 0) {
            market.setInitialImpliedRate(index, initialAnchor, block.timestamp);
            _mint(address(1), lpToReserve);
        }

        _mint(receiver, lpToAccount);

        if (data.length > 0) {
            IPMarketAddRemoveCallback(msg.sender).addLiquidityCallback(
                lpToAccount,
                scyUsed,
                otUsed,
                data
            );
        }

        require(market.totalOt.Uint() <= IERC20(OT).balanceOf(address(this)));
        require(market.totalScy.Uint() <= IERC20(SCY).balanceOf(address(this)));

        _writeState(market);
    }

    function removeLiquidity(
        address receiver,
        uint256 lpToRemove,
        bytes calldata data
    ) external nonReentrant returns (uint256 scyToAccount, uint256 otToAccount) {
        MarketAllParams memory market = readState();

        (scyToAccount, otToAccount) = market.removeLiquidity(lpToRemove);

        IERC20(SCY).safeTransfer(receiver, scyToAccount);
        IERC20(OT).safeTransfer(receiver, otToAccount);

        if (data.length > 0) {
            IPMarketAddRemoveCallback(msg.sender).removeLiquidityCallback(
                lpToRemove,
                scyToAccount,
                otToAccount,
                data
            );
        }

        _burn(address(this), lpToRemove);

        _writeState(market);
    }

    function swapExactOtForScy(
        address receiver,
        uint256 exactOtIn,
        uint256 minScyOut,
        bytes calldata data
    ) external nonReentrant returns (uint256 netScyOut, uint256 netScyToReserve) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketAllParams memory market = readState();

        (netScyOut, netScyToReserve) = market.swapExactOtForScy(
            SCYIndexLib.newIndex(SCY),
            exactOtIn,
            block.timestamp
        );
        require(netScyOut >= minScyOut, "insufficient scy out");
        IERC20(SCY).safeTransfer(receiver, netScyOut);
        IERC20(SCY).safeTransfer(IPMarketFactory(factory).treasury(), netScyToReserve);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactOtIn.neg(), netScyOut.Int(), data);
        }

        // have received enough OT
        require(market.totalOt.Uint() <= IERC20(OT).balanceOf(address(this)));
        _writeState(market);
    }

    function swapScyForExactOt(
        address receiver,
        uint256 exactOtOut,
        uint256 maxScyIn,
        bytes calldata data
    ) external nonReentrant returns (uint256 netScyIn, uint256 netScyToReserve) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketAllParams memory market = readState();

        (netScyIn, netScyToReserve) = market.swapScyForExactOt(
            SCYIndexLib.newIndex(SCY),
            exactOtOut,
            block.timestamp
        );
        require(netScyIn <= maxScyIn, "scy in exceed limit");
        IERC20(OT).safeTransfer(receiver, exactOtOut);
        IERC20(SCY).safeTransfer(IPMarketFactory(factory).treasury(), netScyToReserve);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactOtOut.Int(), netScyIn.neg(), data);
        }

        // have received enough SCY
        require(market.totalScy.Uint() <= IERC20(SCY).balanceOf(address(this)));
        _writeState(market);
    }

    /// @dev this function is just a place holder. Later on the rewards will be transferred to the liquidity minining
    /// instead
    function redeemScyReward() external returns (uint256[] memory outAmounts) {
        outAmounts = ISuperComposableYield(SCY).redeemReward(
            address(this),
            IPMarketFactory(factory).treasury()
        );
    }

    /// the only non-view part in this function is the ISuperComposableYield(SCY).scyIndexCurrent()
    function readState() public view returns (MarketAllParams memory market) {
        MarketStorage storage store = marketStorage;
        market.totalOt = store.totalOt;
        market.totalScy = store.totalScy;
        market.totalLp = totalSupply().Int();
        market.oracleRate = store.oracleRate;
        market.reserveFeePercent = reserveFeePercent;

        market.scalarRoot = scalarRoot;
        market.feeRateRoot = feeRateRoot;
        market.rateOracleTimeWindow = rateOracleTimeWindow;
        market.expiry = expiry;

        market.lastImpliedRate = store.lastImpliedRate;
        market.lastTradeTime = store.lastTradeTime;

        market.updateNewRateOracle(block.timestamp);
    }

    function _writeState(MarketAllParams memory market) internal {
        MarketStorage storage store = marketStorage;

        store.totalOt = market.totalOt.Int128();
        store.totalScy = market.totalScy.Int128();
        store.lastImpliedRate = market.lastImpliedRate.Uint112();
        store.oracleRate = market.oracleRate.Uint112();
        store.lastTradeTime = market.lastTradeTime.Uint32();
    }

    function readTokens()
        external
        view
        returns (
            ISuperComposableYield _SCY,
            IPOwnershipToken _OT,
            IPYieldToken _YT
        )
    {
        _SCY = ISuperComposableYield(SCY);
        _OT = IPOwnershipToken(OT);
        _YT = IPYieldToken(YT);
    }
}
