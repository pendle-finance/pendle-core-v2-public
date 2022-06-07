// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPVeToken.sol";
import "../../interfaces/ISuperComposableYield.sol";
import "../../SuperComposableYield/base-implementations/RewardManager.sol";
import "../../libraries/math/Math.sol";
import "../../libraries/helpers/ArrayLib.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract PendleGauge is RewardManager {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using ArrayLib for address[];

    uint256 private constant TOKENLESS_PRODUCTION = 40;
    address private immutable SCY;
    address private immutable PENDLE;

    IPVeToken public immutable vePENDLE;
    address public immutable gaugeController;

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
     * @dev It is intended to have user's active balance updated when they try to redeem
     */
    function _redeemRewards(address user) internal virtual returns (uint256[] memory) {
        _updateAndDistributeRewards(user);
        _updateUserActiveBalance(user);
        return _doTransferOutRewards(user, user);
    }

    /**
     * @dev since rewardShares will be modified after this function, it should update user reward beforehand
     */
    function _updateUserActiveBalance(address user) internal virtual {
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
        uint256 vePendleBalance = vePENDLE.balanceOf(user);
        uint256 vePendleSupply = vePENDLE.totalSupplyCurrent();
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
        IPGaugeController(gaugeController).claimMarketReward();
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
        _updateRewardIndex();
        if (from != address(0) && from != address(this)) _distributeUserReward(from);
        if (to != address(0) && to != address(this)) _distributeUserReward(to);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256
    ) internal virtual {
        if (from != address(0) && from != address(this)) _updateUserActiveBalance(from);
        if (to != address(0) && to != address(this)) _updateUserActiveBalance(to);
    }
}
