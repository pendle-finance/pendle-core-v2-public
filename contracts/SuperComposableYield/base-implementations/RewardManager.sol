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
        uint128 index;
        uint128 lastBalance;
    }

    struct UserReward {
        uint128 index;
        uint128 accrued;
    }

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    mapping(address => RewardState) public rewardState;
    // user -> token -> reward state
    mapping(address => mapping(address => UserReward)) public userReward;

    function userRewardAccrued(address token, address user) external view returns (uint128) {
        return userReward[token][user].index;
    }

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

            rewardState[token] = RewardState({
                index: rewardIndex.Uint128(),
                lastBalance: currentBalance.Uint128()
            });
        }
    }

    function _distributeUserReward(address user) internal virtual {
        address[] memory rewardTokens = _getRewardTokens();

        uint256 userShares = _rewardSharesUser(user);

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 rewardIndex = rewardState[token].index;
            uint256 userIndex = userReward[token][user].index;

            if (userIndex == 0 && rewardIndex > 0) {
                userIndex = INITIAL_REWARD_INDEX;
            }

            if (rewardIndex == userIndex) {
                // shortcut since deltaIndex == 0
                continue;
            }

            uint256 deltaIndex = rewardIndex - userIndex;
            uint256 rewardDelta = userShares.mulDown(deltaIndex);
            uint256 rewardAccrued = userReward[token][user].accrued + rewardDelta;

            userReward[token][user] = UserReward({
                index: rewardIndex.Uint128(),
                accrued: rewardAccrued.Uint128()
            });
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

            rewardAmounts[i] = userReward[token][user].accrued;
            userReward[token][user].accrued = 0;

            rewardState[token].lastBalance -= rewardAmounts[i].Uint128();

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
