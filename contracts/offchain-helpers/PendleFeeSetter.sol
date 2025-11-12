// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {IPGovernanceProxy} from "../interfaces/IPGovernanceProxy.sol";
import {IPLimitRouter} from "../interfaces/IPLimitRouter.sol";
import {IPMarket, MarketState} from "../interfaces/IPMarket.sol";
import {IPMarketFactory} from "../interfaces/IPMarketFactory.sol";
import {IPYieldToken} from "../interfaces/IPYieldToken.sol";

import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";
import {Errors} from "../core/libraries/Errors.sol";
import {LogExpMath} from "../core/libraries/math/LogExpMath.sol";
import {PMath} from "../core/libraries/math/PMath.sol";

contract PendleFeeSetter is BoringOwnableUpgradeableV2 {
    using PMath for uint256;
    using PMath for int256;
    using LogExpMath for int256;

    event FeeFactorSet(uint128 impliedRateToFeeFactor, uint128 routerLnFeeToLimitLnFeeFactor);
    event SetterSet(address indexed setter);

    uint256 internal constant LIMIT_MAX_LN_FEE_RATE_ROOT = 48_790_164_169_432_003; // ln(1.05)

    address public immutable router;
    IPLimitRouter public immutable limitRouter;
    IPGovernanceProxy public immutable govProxy;

    uint128 public impliedRateToFeeFactor;
    uint128 public routerLnFeeToLimitLnFeeFactor;
    address public setter;

    modifier onlyOwnerOrSetter() {
        require(msg.sender == setter || msg.sender == owner, "not setter or owner");
        _;
    }

    constructor(address _router, address _limitRouter, address _govProxy) {
        _disableInitializers();
        router = _router;
        limitRouter = IPLimitRouter(_limitRouter);
        govProxy = IPGovernanceProxy(_govProxy);
    }

    function initialize(address _owner, uint128 _impliedRateToFeeFactor, uint128 _routerLnFeeToLimitLnFeeFactor)
        external
        initializer
    {
        __BoringOwnableV2_init(_owner);
        _setFeeFactors(_impliedRateToFeeFactor, _routerLnFeeToLimitLnFeeFactor);
    }

    function setFees(address[] memory markets) external onlyOwnerOrSetter {
        uint256 n = markets.length;

        IPGovernanceProxy.Call[] memory calls = new IPGovernanceProxy.Call[](n + 1);

        address[] memory YTs = new address[](n);
        uint256[] memory limitLnFeeRateRoots = new uint256[](n);

        uint256 _impliedRateToFeeFactor = impliedRateToFeeFactor;
        uint256 _routerLnFeeToLimitLnFeeFactor = routerLnFeeToLimitLnFeeFactor;
        for (uint256 i = 0; i < n; ++i) {
            (,, IPYieldToken yt) = IPMarket(markets[i]).readTokens();
            (uint256 routerLnFeeRateRoot, uint256 limitLnFeeRateRoot) =
                _calcFee(_impliedRateToFeeFactor, _routerLnFeeToLimitLnFeeFactor, markets[i]);

            YTs[i] = address(yt);
            limitLnFeeRateRoots[i] = limitLnFeeRateRoot;

            calls[i].target = IPMarket(markets[i]).factory();
            calls[i].callData =
                abi.encodeCall(IPMarketFactory.setOverriddenFee, (router, markets[i], routerLnFeeRateRoot.Uint80()));
        }

        calls[n].target = address(limitRouter);
        calls[n].callData = abi.encodeCall(
            IPLimitRouter.setLnFeeRateRoots, (YTs, limitLnFeeRateRoots, /* allowZeroFees */ false)
        );

        govProxy.aggregateWithScopedAccess(calls);
    }

    function _calcFee(uint256 _impliedRateToFeeFactor, uint256 _routerLnFeeToLimitLnFeeFactor, address market)
        internal
        view
        returns (uint256 routerLnFeeRateRoot, uint256 limitLnFeeRateRoot)
    {
        uint256 marketLnFee = IPMarket(market).getNonOverrideLnFeeRateRoot();
        MarketState memory state = IPMarket(market).readState(router);
        uint256 impliedRate = state.lastLnImpliedRate.Int().exp().Uint();

        uint256 newFee = (impliedRate - PMath.ONE).mulDown(_impliedRateToFeeFactor) + PMath.ONE;
        uint256 newLnFeeRateRoot = newFee.Int().ln().Uint();

        routerLnFeeRateRoot = marketLnFee.min(newLnFeeRateRoot);
        limitLnFeeRateRoot = LIMIT_MAX_LN_FEE_RATE_ROOT.min(routerLnFeeRateRoot.mulDown(_routerLnFeeToLimitLnFeeFactor));

        // Fix up `routerLnFeeRateRoot` for this case:
        // https://github.com/pendle-finance/pendle-core-v2/blob/6169376d0a8c12030307e3d64d02e84b07ffe4f9/contracts/core/Market/v3/PendleMarketFactoryV3.sol#L131-L135
        if (routerLnFeeRateRoot == marketLnFee) routerLnFeeRateRoot = 0;
    }

    function readFeesAndImpliedRate(address[] memory markets)
        external
        view
        returns (
            uint256[] memory routerLnFeeRateRoots,
            uint256[] memory limitLnFeeRateRoots,
            uint256[] memory lnImpliedRates
        )
    {
        uint256 n = markets.length;
        routerLnFeeRateRoots = new uint256[](n);
        limitLnFeeRateRoots = new uint256[](n);
        lnImpliedRates = new uint256[](n);

        for (uint256 i = 0; i < n; ++i) {
            MarketState memory state = IPMarket(markets[i]).readState(router);
            routerLnFeeRateRoots[i] = state.lnFeeRateRoot;
            lnImpliedRates[i] = state.lastLnImpliedRate;

            (,, IPYieldToken yt) = IPMarket(markets[i]).readTokens();
            try limitRouter.getLnFeeRateRoot(address(yt)) returns (uint256 _fee) {
                limitLnFeeRateRoots[i] = _fee;
            } catch {
                limitLnFeeRateRoots[i] = 0;
            }
        }
    }

    // ============================== Admin functions ==============================

    function setFeeFactors(uint128 _impliedRateToFeeFactor, uint128 _routerLnFeeToLimitLnFeeFactor) external onlyOwner {
        _setFeeFactors(_impliedRateToFeeFactor, _routerLnFeeToLimitLnFeeFactor);
    }

    function _setFeeFactors(uint128 _impliedRateToFeeFactor, uint128 _routerLnFeeToLimitLnFeeFactor) internal {
        impliedRateToFeeFactor = _impliedRateToFeeFactor;
        routerLnFeeToLimitLnFeeFactor = _routerLnFeeToLimitLnFeeFactor;

        emit FeeFactorSet(_impliedRateToFeeFactor, _routerLnFeeToLimitLnFeeFactor);
    }

    function setSetter(address _setter) external onlyOwner {
        setter = _setter;
        emit SetterSet(setter);
    }
}
