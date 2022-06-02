// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPGauge.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPVeToken.sol";
import "../../interfaces/ISuperComposableYield.sol";
import "../../SuperComposableYield/base-implementations/RewardManager.sol";
import "../../libraries/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract PendleGauge is RewardManager {
    using Math for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant TOKENLESS_PRODUCTION = 40;
    address public immutable pendle;
    IPVeToken public immutable vePendle;
    address public immutable gaugeController;

    uint256 public totalActiveSupply;
    mapping(address => uint256) public activeBalance;

    constructor(address _vePendle, address _gaugeController) {
        vePendle = IPVeToken(_vePendle);
        gaugeController = _gaugeController;
        pendle = IPGaugeController(gaugeController).pendle();
    }

    /**
     * @dev It is intended to have msg.sender active balance updated when they try to redeem
     */
    function redeemReward(address receiver) external returns (uint256[] memory) {
        // Change to allow redeeming for others
        address user = msg.sender;
        _updateAndDistributeRewards(user);
        _updateUserActiveBalance(user);
        return _doTransferOutRewards(user, receiver);
    }

    function _stakedBalance(address user) internal view virtual returns (uint256);

    function _totalStaked() internal view virtual returns (uint256);

    /**
     * @dev since rewardShares will be modified after this function, it should update user reward beforehand
     */
    function _updateUserActiveBalance(address user) internal {
        uint256 lpBalance = _stakedBalance(user);
        uint256 vePendleBalance = vePendle.balanceOf(user);
        uint256 vePendleSupply = vePendle.totalSupplyCurrent();
        // Inspired by Curve's Gauge
        uint256 veBoostedLpBalance = (lpBalance * TOKENLESS_PRODUCTION) / 100;
        if (vePendleSupply > 0) {
            veBoostedLpBalance +=
                // Hmm will _totalStaked << vePendleSupply?
                (((_totalStaked() * vePendleBalance) / vePendleSupply) *
                    (100 - TOKENLESS_PRODUCTION)) /
                100;
        }
        // I really hate the reuse of variables like this
        uint256 newActiveBalance = Math.min(veBoostedLpBalance, lpBalance);

        totalActiveSupply = totalActiveSupply - activeBalance[user] + newActiveBalance;
        activeBalance[user] = newActiveBalance;
    }

    function _redeemExternalReward() internal virtual override {
        IPGaugeController(gaugeController).claimMarketReward();
    }

    function _rewardSharesTotal() internal virtual override returns (uint256) {
        return totalActiveSupply;
    }

    function _rewardSharesUser(address user) internal virtual override returns (uint256) {
        return activeBalance[user];
    }
}
