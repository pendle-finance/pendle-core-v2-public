// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../interfaces/ISuperComposableYield.sol";
import "../interfaces/IRewardManager.sol";
import "./math/Math.sol";
import "./helpers/TokenHelper.sol";
import "./helpers/ArrayLib.sol";

/// This RewardManager can be used with any contracts, regardless of what tokens that contract stores
/// since the RewardManager will maintain its own internal balance
abstract contract RewardManager is IRewardManager, TokenHelper {
    using Math for uint256;
    using ArrayLib for uint256[];

    struct RewardState {
        uint128 index;
        uint128 lastBalance;
    }

    struct UserReward {
        uint128 index;
        uint128 accrued;
    }

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    uint256 public lastRewardBlock;

    mapping(address => RewardState) public rewardState;
    // token -> user -> reward state
    mapping(address => mapping(address => UserReward)) public userReward;

    function userRewardAccrued(address token, address user) external view returns (uint128) {
        return userReward[token][user].accrued;
    }

    function _updateAndDistributeRewards(address user) internal virtual {
        _updateRewardIndex();
        _distributeUserReward(user);
    }

    function _updateRewardIndex() internal virtual {
        if (lastRewardBlock == block.number) return;
        lastRewardBlock = block.number;

        address[] memory rewardTokens = _getRewardTokens();
        uint256[] memory preBalances = _selfBalances(rewardTokens);

        _redeemExternalReward();

        uint256[] memory accruedAmounts = _selfBalances(rewardTokens).sub(preBalances);

        uint256 totalShares = _rewardSharesTotal();

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 rewardIndex = rewardState[token].index;

            if (rewardIndex == 0) rewardIndex = INITIAL_REWARD_INDEX;
            if (totalShares != 0) rewardIndex += accruedAmounts[i].divDown(totalShares);

            rewardState[token].index = rewardIndex.Uint128();
            rewardState[token].lastBalance += accruedAmounts[i].Uint128();
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

            // if rewardAmounts[i] == 0, .accured is already == 0

            if (rewardAmounts[i] != 0) {
                userReward[token][user].accrued = 0;
                rewardState[token].lastBalance -= rewardAmounts[i].Uint128();
                _transferOut(token, receiver, rewardAmounts[i]);
            }
        }
    }

    /// @dev to be overriden if there is rewards
    function _redeemExternalReward() internal virtual;

    function _rewardSharesTotal() internal view virtual returns (uint256);

    function _rewardSharesUser(
        address /*user*/
    ) internal view virtual returns (uint256);

    function _getRewardTokens() internal view virtual returns (address[] memory);
}
