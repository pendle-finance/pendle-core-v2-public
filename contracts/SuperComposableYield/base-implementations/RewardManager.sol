// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../../interfaces/ISuperComposableYield.sol";
import "../../interfaces/IRewardManager.sol";
import "../../libraries/math/Math.sol";
import "../../libraries/TokenHelper.sol";

abstract contract RewardManager is IRewardManager, TokenHelper {
    using Math for uint256;

    uint256 public lastRewardBlock;

    struct RewardState {
        uint256 index;
        uint256 lastBalance;
    }

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    mapping(address => RewardState) public rewardState;
    mapping(address => mapping(address => uint256)) public userRewardAccrued;
    mapping(address => mapping(address => uint256)) public userRewardIndex;

    function _getRewardTokens() internal view virtual returns (address[] memory);

    function _updateAndDistributeRewards(address user) internal virtual {
        _updateRewardIndex();
        _distributeUserReward(user);
    }

    function _updateRewardIndex() internal virtual {
        if (lastRewardBlock == block.number) return;
        lastRewardBlock = block.number;

        _redeemExternalReward();

        uint256 totalShares = _rewardSharesTotal();

        address[] memory rewardTokens = _getRewardTokens();

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 rewardIndex = rewardState[token].index;

            uint256 currentBalance = _selfBalance(token);
            uint256 rewardAccrued = currentBalance - rewardState[token].lastBalance;

            if (rewardIndex == 0) rewardIndex = INITIAL_REWARD_INDEX;
            if (totalShares != 0) rewardIndex += rewardAccrued.divDown(totalShares);

            rewardState[token] = RewardState({ index: rewardIndex, lastBalance: currentBalance });
        }
    }

    function _distributeUserReward(address user) internal virtual {
        address[] memory rewardTokens = _getRewardTokens();

        uint256 userShares = _rewardSharesUser(user);

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 rewardIndex = rewardState[token].index;
            uint256 userIndex = userRewardIndex[user][token];

            if (userIndex == 0 && rewardIndex > 0) {
                userIndex = INITIAL_REWARD_INDEX;
            }

            uint256 deltaIndex = rewardIndex - userIndex;
            uint256 rewardDelta = userShares.mulDown(deltaIndex);
            uint256 rewardAccrued = userRewardAccrued[user][token] + rewardDelta;

            userRewardAccrued[user][token] = rewardAccrued;
            userRewardIndex[user][token] = rewardIndex;
        }
    }

    function _doTransferOutRewards(address user, address receiver)
        internal
        virtual
        returns (uint256[] memory rewardAmounts)
    {
        address[] memory rewardTokens = _getRewardTokens();

        rewardAmounts = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            rewardAmounts[i] = userRewardAccrued[user][token];
            userRewardAccrued[user][token] = 0;

            rewardState[token].lastBalance -= rewardAmounts[i];

            if (rewardAmounts[i] != 0) {
                _transferOut(token, receiver, rewardAmounts[i]);
            }
        }
    }

    /// @dev to be overriden if there is rewards
    function _redeemExternalReward() internal virtual;

    /// @dev to be overriden if there is rewards
    function _rewardSharesTotal() internal virtual returns (uint256);

    /// @dev to be overriden if there is rewards
    function _rewardSharesUser(
        address /*user*/
    ) internal virtual returns (uint256);
}
