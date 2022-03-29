// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleBaseToken.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../LiquidYieldToken/ILiquidYieldToken.sol";
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
    address public immutable LYT;

    uint256 public immutable scalarRoot;
    uint256 public immutable feeRateRoot; // allow fee to be changable?
    int256 public immutable anchorRoot;
    int8 public immutable reserveFeePercent;

    MarketStorage public _marketState;

    constructor(
        address _OT,
        uint256 _feeRateRoot,
        uint256 _scalarRoot,
        int256 _anchorRoot,
        uint8 _reserveFeePercent
    ) PendleBaseToken(NAME, SYMBOL, 18, IPOwnershipToken(_OT).expiry()) {
        OT = _OT;
        LYT = IPOwnershipToken(_OT).LYT();
        feeRateRoot = _feeRateRoot;
        scalarRoot = _scalarRoot;

        require(_reserveFeePercent <= 100, "invalid fee rate");
        reserveFeePercent = int8(_reserveFeePercent);
        anchorRoot = _anchorRoot;
    }

    function addLiquidity(
        address recipient,
        uint256 lytDesired,
        uint256 otDesired,
        bytes calldata data
    )
        external
        nonReentrant
        returns (
            uint256 lpToAccount,
            uint256 lytUsed,
            uint256 otUsed
        )
    {
        MarketParameters memory market = readState();

        uint256 lpToReserve;
        (lpToReserve, lpToAccount, lytUsed, otUsed) = market.addLiquidity(lytDesired, otDesired);

        // initializing the market
        if (lpToReserve != 0) {
            market.setInitialImpliedRate(timeToExpiry());
            _mint(address(1), lpToReserve);
        }

        _mint(recipient, lpToAccount);

        IPMarketAddRemoveCallback(msg.sender).addLiquidityCallback(
            lpToAccount,
            lytUsed,
            otUsed,
            data
        );

        require(market.totalOt.Uint() <= IERC20(OT).balanceOf(address(this)));
        require(market.totalLyt.Uint() <= IERC20(LYT).balanceOf(address(this)));

        _writeState(market);
    }

    function removeLiquidity(
        address recipient,
        uint256 lpToRemove,
        bytes calldata data
    ) external nonReentrant returns (uint256 lytToAccount, uint256 otToAccount) {
        MarketParameters memory market = readState();

        (lytToAccount, otToAccount) = market.removeLiquidity(lpToRemove);

        IERC20(LYT).safeTransfer(recipient, lytToAccount);
        IERC20(OT).safeTransfer(recipient, otToAccount);

        IPMarketAddRemoveCallback(msg.sender).removeLiquidityCallback(
            lpToRemove,
            lytToAccount,
            otToAccount,
            data
        );

        _burn(address(this), lpToRemove);

        _writeState(market);
    }

    function swap(
        address recipient,
        int256 otToAccount,
        bytes calldata data
    ) external nonReentrant returns (int256 netLytToAccount) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketParameters memory market = readState();

        int256 netLytToReserve;

        (netLytToAccount, netLytToReserve) = market.calculateTrade(otToAccount, timeToExpiry());

        if (netLytToAccount > 0) IERC20(LYT).safeTransfer(recipient, netLytToAccount.Uint());
        if (otToAccount > 0) IERC20(OT).safeTransfer(recipient, otToAccount.Uint());

        IPMarketSwapCallback(recipient).swapCallback(otToAccount, netLytToAccount, data);

        require(market.totalOt.Uint() <= IERC20(OT).balanceOf(address(this)));
        require(market.totalLyt.Uint() <= IERC20(LYT).balanceOf(address(this)));

        IERC20(LYT).safeTransfer(IPMarketFactory(factory).treasury(), netLytToReserve.Uint());
        _writeState(market);
    }

    /// the only non-view part in this function is the ILiquidYieldToken(LYT).lytIndexCurrent()
    function readState() public returns (MarketParameters memory market) {
        MarketStorage storage store = _marketState;
        market.expiry = expiry;
        market.totalOt = store.totalOt;
        market.totalLyt = store.totalLyt;
        market.totalLp = totalSupply().Int();
        market.lastImpliedRate = store.lastImpliedRate;
        market.lytRate = ILiquidYieldToken(LYT).lytIndexCurrent();
        market.feeRateRoot = feeRateRoot;
        market.reserveFeePercent = reserveFeePercent;
        market.anchorRoot = anchorRoot;
    }

    function timeToExpiry() public view returns (uint256 res) {
        res = (expiry >= block.timestamp) ? expiry - block.timestamp : 0;
    }

    function _writeState(MarketParameters memory market) internal {
        MarketStorage storage store = _marketState;
        // shall we verify lp here?
        // hmm should we verify the sum right after callback instead?

        store.totalOt = market.totalOt.Int128();
        store.totalLyt = market.totalLyt.Int128();
        store.lastImpliedRate = market.lastImpliedRate.Uint32();
    }

    function _selfBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
