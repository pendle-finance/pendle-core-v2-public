// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./base/PendleBaseToken.sol";
import "../interfaces/IPMarketCallback.sol";
import "../interfaces/IPOwnershipToken.sol";
import "../interfaces/IPLiquidYieldToken.sol";
import "../interfaces/IPMarket.sol";
import "../interfaces/IPMarketFactory.sol";

import "../libraries/math/LogExpMath.sol";
import "../libraries/math/FixedPoint.sol";
import "../libraries/math/MarketMathLib.sol";

// solhint-disable reason-string
contract PendleMarket is PendleBaseToken, IPMarket {
    using FixedPoint for uint256;
    using FixedPoint for int256;
    using LogExpMath for uint256;
    using MarketMathLib for MarketParameters;
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
    uint8 public immutable reserveFeePercent;

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
        reserveFeePercent = _reserveFeePercent;
        anchorRoot = _anchorRoot;
    }

    function addLiquidity(address recipient) external returns (uint256 lpToUser) {
        MarketParameters memory market = readState();

        uint256 lytDesired = _selfBalance(LYT) - market.totalLyt;
        uint256 otDesired = _selfBalance(OT) - market.totalOt;

        uint256 lpToReserve;
        (lpToReserve, lpToUser, , ) = market.addLiquidity(lytDesired, otDesired);

        // initializing the market
        if (lpToReserve != 0) {
            market.setInitialImpliedRate(market.expiry - block.timestamp);
            _mint(address(1), lpToReserve);
        }

        _mint(recipient, lpToUser);
        _writeAndVerifyState(market);
    }

    function removeLiquidity(address recipient) external returns (uint256 lytOut, uint256 otOut) {
        MarketParameters memory market = readState();

        uint256 lpToRemove = balanceOf(address(this));

        (lytOut, otOut) = market.removeLiquidity(lpToRemove);

        _burn(address(this), lpToRemove);
        IERC20(LYT).transfer(recipient, lytOut);
        IERC20(OT).transfer(recipient, otOut);

        _writeAndVerifyState(market);
    }

    function swap(
        address recipient,
        int256 otToAccount,
        bytes calldata cbData
    ) external returns (int256 netLytToAccount, bytes memory cbRes) {
        require(block.timestamp < expiry, "MARKET_EXPIRED");

        MarketParameters memory market = readState();

        uint256 netLytToReserve;

        (netLytToAccount, netLytToReserve) = market.calculateTrade(
            otToAccount,
            market.expiry - block.timestamp
        );

        if (netLytToAccount > 0) {
            // need to push LYT & pull OT
            IERC20(LYT).transfer(recipient, netLytToAccount.toUint());
        } else {
            // need to push OT & pull LYT
            IERC20(OT).transfer(recipient, otToAccount.neg().toUint());
        }
        cbRes = IPMarketCallback(msg.sender).callback(otToAccount, netLytToAccount, cbData);

        IERC20(LYT).transfer(IPMarketFactory(factory).treasury(), netLytToReserve);
        _writeAndVerifyState(market);
    }

    function readState() public returns (MarketParameters memory market) {
        MarketStorage storage store = _marketState;
        market.expiry = expiry;
        market.totalOt = store.totalOt;
        market.totalLyt = store.totalLyt;
        market.totalLp = totalSupply();
        market.lastImpliedRate = store.lastImpliedRate;
        market.lytRate = IPLiquidYieldToken(LYT).exchangeRateCurrent();
        market.feeRateRoot = feeRateRoot;
        market.reserveFeePercent = reserveFeePercent;
        market.anchorRoot = anchorRoot;
    }

    function _writeAndVerifyState(MarketParameters memory market) internal {
        MarketStorage storage store = _marketState;
        require(market.totalOt <= IERC20(OT).balanceOf(address(this)));
        require(market.totalLyt <= IERC20(LYT).balanceOf(address(this)));
        // shall we verify lp here?
        // hmm should we verify the sum right after callback instead?

        store.totalOt = market.totalOt.toUint128();
        store.totalLyt = market.totalLyt.toUint128();
        store.lastImpliedRate = market.lastImpliedRate.toUint32();
    }

    function _selfBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
