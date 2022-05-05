// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;

import "../../interfaces/IPGaugeController.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../SuperComposableYield/implementations/RewardManager.sol";
import "../../libraries/math/Math.sol";
import "../../interfaces/IPGauge.sol";
import "../../interfaces/IPGaugeController.sol";
import "../../interfaces/IPMarketFactory.sol";

/**
 * @dev Gauge controller provides no write function to any party other than voting controller
 * @dev Gauge controller will receive (lpToken, pendle per sec) from voting controller and
 * set it directly to contract state
 *
 * @dev All of the core data in this function will be set to private to prevent unintended assignments
 * on inheritting contracts
 */

contract PendleGaugeController is RewardManager, IPGaugeController {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 private totalVotes;
    uint256 private accumulatedPendle;

    mapping(address => uint256) private lpVotes;

    address public immutable pendle;
    IPMarketFactory internal immutable marketFactory;

    constructor(address _pendle, address _marketFactory) {
        pendle = _pendle;
        marketFactory = IPMarketFactory(_marketFactory);
    }

    function getRewardTokens() public view virtual override returns (address[] memory res) {
        res = new address[](1);
        res[0] = pendle;
    }

    function updateAndGetGaugeReward(address gauge) external returns (uint256) {
        _updateUserRewardSkipGlobal(gauge);
        return userReward[gauge][pendle].accruedReward;
    }

    /**
     * @dev this function is expected to be called by gauge only
     */
    function redeemLpStakerReward(address staker, uint256 amount) external {
        address gauge = msg.sender;
        address market = IPGauge(gauge).market();
        require(marketFactory.verifyGauge(market, gauge), "market gauge not matched");

        _updateUserReward(market);
        userReward[market][pendle].accruedReward -= amount;

        if (amount != 0) {
            IERC20(pendle).safeTransfer(staker, amount);
        }
    }

    /**
     * @dev this contract is designed to have pendle in its balance at any time
     * without redeeming externally so there is not a need for redeemExternalReward
     */
    function _updateGlobalReward() internal virtual override {
        uint256 totalShares = _rewardSharesTotal();
        address[] memory rewardTokens = getRewardTokens();
        _initGlobalReward(rewardTokens);

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 currentRewardBalance = accumulatedPendle;

            if (totalShares != 0) {
                globalReward[token].index += (currentRewardBalance -
                    globalReward[token].lastBalance).divDown(totalShares);
            }

            globalReward[token].lastBalance = currentRewardBalance;
        }
    }

    function _rewardSharesTotal() internal view virtual override returns (uint256) {
        return totalVotes;
    }

    function _rewardSharesUser(address lpToken) internal view virtual override returns (uint256) {
        return lpVotes[lpToken];
    }

    function _updateLpVote(
        uint256 pendleAcquired,
        address lpToken,
        uint256 newVote
    ) internal {
        accumulatedPendle += pendleAcquired;
        _updateUserReward(lpToken);

        uint256 previousVote = lpVotes[lpToken];
        totalVotes = totalVotes - previousVote + newVote;
        lpVotes[lpToken] = newVote;
    }

    /// @dev this function is intentionally left empty
    function _redeemExternalReward() internal virtual override {}
}
