// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IPGauge.sol";
import "../../interfaces/IPVeToken.sol";
import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/ISuperComposableYield.sol";

import "../RewardManager/RewardManager.sol";

/**
Invariants to maintain:
- before any changes to active balance, updateAndDistributeRewards() must be called
 */
abstract contract PendleGauge is RewardManager, IPGauge {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using ArrayLib for address[];

    address private immutable SCY;

    uint256 internal constant TOKENLESS_PRODUCTION = 40;

    address internal immutable PENDLE;
    IPVeToken internal immutable vePENDLE;
    address internal immutable gaugeController;

    uint256 public totalActiveSupply;
    mapping(address => uint256) public activeBalance;

    constructor(
        address _SCY,
        address _vePendle,
        address _gaugeController
    ) {
        SCY = _SCY;
        vePENDLE = IPVeToken(_vePendle);
        gaugeController = _gaugeController;
        PENDLE = IPGaugeController(gaugeController).pendle();
    }

    /**
     * @dev Since rewardShares is based on activeBalance, user's activeBalance must be updated AFTER
        rewards is updated
     * @dev It's intended to have user's activeBalance updated when rewards is redeemed
     */
    function _redeemRewards(address user) internal virtual returns (uint256[] memory) {
        _updateAndDistributeRewards(user);
        _updateUserActiveBalance(user);
        return _doTransferOutRewards(user, user);
    }

    function _updateUserActiveBalance(address user) internal virtual {
        _updateUserActiveBalanceForTwo(user, address(0));
    }

    function _updateUserActiveBalanceForTwo(address user1, address user2) internal virtual {
        if (user1 != address(0) && user1 != address(this)) _updateUserActiveBalancePrivate(user1);
        if (user2 != address(0) && user2 != address(this)) _updateUserActiveBalancePrivate(user2);
    }

    /**
     * @dev should only be callable from `_updateUserActiveBalanceForTwo` to guarantee user != address(0) && user != address(this)
     */
    function _updateUserActiveBalancePrivate(address user) private {
        assert(user != address(0) && user != address(this));

        uint256 lpBalance = _stakedBalance(user);
        uint256 veBoostedLpBalance = _calcVeBoostedLpBalance(user, lpBalance);

        uint256 newActiveBalance = Math.min(veBoostedLpBalance, lpBalance);

        totalActiveSupply = totalActiveSupply - activeBalance[user] + newActiveBalance;
        activeBalance[user] = newActiveBalance;
    }

    function _calcVeBoostedLpBalance(address user, uint256 lpBalance)
        internal
        virtual
        returns (uint256)
    {
        (uint256 vePendleSupply, uint256 vePendleBalance) = vePENDLE.totalSupplyAndBalanceCurrent(
            user
        );
        // Inspired by Curve's Gauge
        uint256 veBoostedLpBalance = (lpBalance * TOKENLESS_PRODUCTION) / 100;
        if (vePendleSupply > 0) {
            veBoostedLpBalance +=
                (((_totalStaked() * vePendleBalance) / vePendleSupply) *
                    (100 - TOKENLESS_PRODUCTION)) /
                100;
        }
        return veBoostedLpBalance;
    }

    function _redeemExternalReward() internal virtual override {
        ISuperComposableYield(SCY).claimRewards(address(this));
        IPGaugeController(gaugeController).redeemMarketReward();
    }

    function _stakedBalance(address user) internal view virtual returns (uint256);

    function _totalStaked() internal view virtual returns (uint256);

    function _rewardSharesTotal() internal view virtual override returns (uint256) {
        return totalActiveSupply;
    }

    function _rewardSharesUser(address user) internal view virtual override returns (uint256) {
        return activeBalance[user];
    }

    function _getRewardTokens() internal view virtual override returns (address[] memory) {
        address[] memory SCYRewards = ISuperComposableYield(SCY).getRewardTokens();
        if (SCYRewards.contains(PENDLE)) return SCYRewards;
        return SCYRewards.append(PENDLE);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal virtual {
        _updateAndDistributeRewardsForTwo(from, to);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256
    ) internal virtual {
        _updateUserActiveBalanceForTwo(from, to);
    }
}
