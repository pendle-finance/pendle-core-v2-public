// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPGauge.sol";
import "../../interfaces/IPMarket.sol";
import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPVeToken.sol";
import "../../SuperComposableYield/ISuperComposableYield.sol";
import "../../SuperComposableYield/implementations/RewardManager.sol";
import "../../libraries/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev this contract will have the rewardTokens property a little different from its original meaning
 * The first N-1 reward tokens will be market's scy reward tokens
 * The N-th reward token will be pendle, but represented by address(0)
 * This design aims to avoid the case when pendle is actually one of the rewardTokens in SCY
 */
// comments are wrong here
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
        _updateUserReward(user);
        _updateUserActiveBalance(user);
        return _doTransferOutRewardsForUser(user, receiver);
    }

    function _stakedBalance(address user) internal view virtual returns (uint256);

    function _totalStaked() internal view virtual returns (uint256);

    /**
     * @dev since rewardShares will be modified after this function, it should update user reward beforehand
     */
    function _updateUserActiveBalance(address user) internal {
        uint256 lpBalance = _stakedBalance(user);
        uint256 vePendleBalance = vePendle.balanceOf(user);
        uint256 vePendleSupply = vePendle.updateAndGetTotalSupply();
        // Inspired by Curve's Gauge
        uint256 newActiveBalance = (lpBalance * TOKENLESS_PRODUCTION) / 100;
        if (vePendleSupply > 0) {
            newActiveBalance +=
                // Hmm will _totalStaked << vePendleSupply?
                (((_totalStaked() * vePendleBalance) / vePendleSupply) *
                    (100 - TOKENLESS_PRODUCTION)) /
                100;
        }
        // I really hate the reuse of variables like this
        newActiveBalance = Math.min(newActiveBalance, lpBalance);

        totalActiveSupply = totalActiveSupply - activeBalance[user] + newActiveBalance;
        activeBalance[user] = newActiveBalance;
    }

    function _redeemExternalReward() internal virtual override {
        IPGaugeController(gaugeController).pullMarketReward();
    }

    function _rewardSharesTotal() internal virtual override returns (uint256) {
        return totalActiveSupply;
    }

    function _rewardSharesUser(address user) internal virtual override returns (uint256) {
        return activeBalance[user];
    }

    function _beforeEmergencyRemoveLiquidity(address user) internal {
        activeBalance[user] = 0;

        address[] memory rewardTokens = getRewardTokens();
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];
            userReward[user][token].accruedReward = 0;
        }
    }
}
