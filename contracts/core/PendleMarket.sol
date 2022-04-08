// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./PendleBaseToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../SuperComposableYield/ISuperComposableYield.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPMarketFactory.sol";
import "../interfaces/IPMarketSwapCallback.sol";
import "../interfaces/IPMarketAddRemoveCallback.sol";

import "../libraries/math/LogExpMath.sol";
import "../libraries/math/FixedPoint.sol";
import "../libraries/math/MarketMathLib.sol";

import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";

// solhint-disable reason-string
contract PendleMarket is PendleBaseToken, IPMarket, ReentrancyGuard {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using FixedPoint for uint128;
    using LogExpMath for uint256;
    using MarketMathLib for MarketParameters;
    using SafeERC20 for IERC20;
    // make it ultra simple

    // careful, the reserve of the market shouldn't be interferred by external factors
    // maybe convert all time to uint32?
    // do the stateful & view stuff?
    string private constant NAME = "Pendle Market";
    string private constant SYMBOL = "PENDLE-LPT";
    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint8 private constant DECIMALS = 18;
    int256 internal constant RATE_PRECISION = 1e9;

    address public immutable OT;
    address public immutable SCY;

    int256 public immutable scalarRoot;
    uint256 public immutable feeRateRoot; // allow fee to be changable?
    int256 public immutable anchorRoot;

    uint256 public immutable rateOracleTimeWindow;
    int8 public immutable reserveFeePercent;

    MarketStorage public marketStorage;

    constructor(
        address _OT,
        uint256 _rateOracleTimeWindow,
        uint256 _feeRateRoot,
        int256 _scalarRoot,
        int256 _anchorRoot,
        uint8 _reserveFeePercent
    ) PendleBaseToken(NAME, SYMBOL, 18, IPOwnershipToken(_OT).expiry()) {
        OT = _OT;
        SCY = IPOwnershipToken(_OT).SCY();
        feeRateRoot = _feeRateRoot;
        scalarRoot = _scalarRoot;
        rateOracleTimeWindow = _rateOracleTimeWindow;

        require(_reserveFeePercent <= 100, "invalid fee rate");
        reserveFeePercent = int8(_reserveFeePercent);
        anchorRoot = _anchorRoot;
    }

    function addLiquidity(
        address recipient,
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
        MarketParameters memory market = readState();

        uint256 lpToReserve;
        (lpToReserve, lpToAccount, scyUsed, otUsed) = market.addLiquidity(scyDesired, otDesired);

        // initializing the market
        if (lpToReserve != 0) {
            market.setInitialImpliedRate(market.getTimeToExpiry());
            _mint(address(1), lpToReserve);
        }

        _mint(recipient, lpToAccount);

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
        address recipient,
        uint256 lpToRemove,
        bytes calldata data
    ) external nonReentrant returns (uint256 scyToAccount, uint256 otToAccount) {
        MarketParameters memory market = readState();

        (scyToAccount, otToAccount) = market.removeLiquidity(lpToRemove);

        IERC20(SCY).safeTransfer(recipient, scyToAccount);
        IERC20(OT).safeTransfer(recipient, otToAccount);

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

    function swapExactOtForSCY(
        address recipient,
        uint256 exactOtIn,
        uint256 minSCYOut,
        bytes calldata data
    ) external nonReentrant returns (uint256 netSCYOut, uint256 netSCYToReserve) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketParameters memory market = readState();

        (netSCYOut, netSCYToReserve) = market.calcExactOtForSCY(exactOtIn, block.timestamp);
        require(netSCYOut >= minSCYOut, "insufficient scy out");
        IERC20(SCY).safeTransfer(recipient, netSCYOut);
        IERC20(SCY).safeTransfer(IPMarketFactory(factory).treasury(), netSCYToReserve);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactOtIn.neg(), netSCYOut.Int(), data);
        }

        // have received enough OT
        require(market.totalOt.Uint() <= IERC20(OT).balanceOf(address(this)));
        _writeState(market);
    }

    function swapSCYForExactOt(
        address recipient,
        uint256 exactOtOut,
        uint256 maxSCYIn,
        bytes calldata data
    ) external nonReentrant returns (uint256 netSCYIn, uint256 netSCYToReserve) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketParameters memory market = readState();

        (netSCYIn, netSCYToReserve) = market.calcSCYForExactOt(exactOtOut, block.timestamp);
        require(netSCYIn <= maxSCYIn, "scy in exceed limit");
        IERC20(OT).safeTransfer(recipient, exactOtOut);
        IERC20(SCY).safeTransfer(IPMarketFactory(factory).treasury(), netSCYToReserve);

        if (data.length > 0) {
            IPMarketSwapCallback(msg.sender).swapCallback(exactOtOut.Int(), netSCYIn.neg(), data);
        }

        // have received enough SCY
        require(market.totalScy.Uint() <= IERC20(SCY).balanceOf(address(this)));
        _writeState(market);
    }

    /// the only non-view part in this function is the ISuperComposableYield(SCY).scyIndexCurrent()
    function readState() public returns (MarketParameters memory market) {
        MarketStorage storage store = marketStorage;
        market.totalOt = store.totalOt;
        market.totalScy = store.totalScy;
        market.totalLp = totalSupply().Int();
        market.scyRate = ISuperComposableYield(SCY).scyIndexCurrent();
        market.oracleRate = store.oracleRate;
        market.reserveFeePercent = reserveFeePercent;

        market.scalarRoot = scalarRoot;
        market.feeRateRoot = feeRateRoot;
        market.anchorRoot = anchorRoot;
        market.rateOracleTimeWindow = rateOracleTimeWindow;
        market.expiry = expiry;

        market.lastImpliedRate = store.lastImpliedRate;
        market.lastTradeTime = store.lastTradeTime;

        market.updateNewRateOracle(block.timestamp);
    }

    function _writeState(MarketParameters memory market) internal {
        MarketStorage storage store = marketStorage;

        store.totalOt = market.totalOt.Int128();
        store.totalScy = market.totalScy.Int128();
        store.lastImpliedRate = market.lastImpliedRate.Uint32();
        store.oracleRate = market.oracleRate.Uint112();
        store.lastTradeTime = market.lastTradeTime.Uint32();
    }
}
