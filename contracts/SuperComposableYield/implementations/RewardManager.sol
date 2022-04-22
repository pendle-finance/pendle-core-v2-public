// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../ISuperComposableYield.sol";
import "./IRewardManager.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../libraries/math/Math.sol";

abstract contract RewardManager is IRewardManager {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct GlobalReward {
        uint256 index;
        uint256 lastBalance;
    }

    struct UserReward {
        uint256 lastIndex;
        uint256 accruedReward;
    }

    uint256 public lastRewardUpdateBlock;

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    mapping(address => GlobalReward) internal globalReward;
    mapping(address => mapping(address => UserReward)) internal userReward;

    function getGlobalReward(address rewardToken)
        external
        view
        returns (uint256 index, uint256 lastBalance)
    {
        GlobalReward memory reward = globalReward[rewardToken];
        return (reward.index, reward.lastBalance);
    }

    function getUserReward(address user, address rewardToken)
        external
        view
        returns (uint256 lastIndex, uint256 accruedReward)
    {
        UserReward memory reward = userReward[user][rewardToken];
        return (reward.lastIndex, reward.accruedReward);
    }

    function getRewardTokens() public view virtual override returns (address[] memory);

    function _doTransferOutRewardsForUser(address user, address receiver)
        internal
        virtual
        returns (uint256[] memory outAmounts)
    {
        address[] memory rewardTokens = getRewardTokens();

        outAmounts = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            outAmounts[i] = userReward[user][token].accruedReward;
            userReward[user][token].accruedReward = 0;

            globalReward[token].lastBalance -= outAmounts[i];

            if (outAmounts[i] != 0) {
                IERC20(token).safeTransfer(receiver, outAmounts[i]);
            }
        }
    }

    function _updateUserReward(address user) internal virtual {
        _updateGlobalReward();
        _updateUserRewardSkipGlobal(user);
    }

    function _updateGlobalReward() internal virtual {
        if (!_shouldUpdateGlobalReward()) return;
        _redeemExternalReward();

        uint256 totalShares = _rewardSharesTotal();

        address[] memory rewardTokens = getRewardTokens();
        _initGlobalReward(rewardTokens);

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 currentRewardBalance = IERC20(token).balanceOf(address(this));

            if (totalShares != 0) {
                globalReward[token].index += (currentRewardBalance -
                    globalReward[token].lastBalance).divDown(totalShares);
            }

            globalReward[token].lastBalance = currentRewardBalance;
        }
    }

    function _updateUserRewardSkipGlobal(address user) internal virtual {
        address[] memory rewardTokens = getRewardTokens();

        uint256 userShares = _rewardSharesUser(user);

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 userLastIndex = userReward[user][token].lastIndex;

            if (userLastIndex == globalReward[token].index) continue;

            if (userLastIndex == 0) {
                // first time receiving this reward
                userReward[user][token].lastIndex = globalReward[token].index;
                continue;
            }

            uint256 rewardAmountPerUnit = globalReward[token].index - userLastIndex;
            uint256 rewardFromUnit = userShares.mulDown(rewardAmountPerUnit);

            userReward[user][token].accruedReward += rewardFromUnit;
            userReward[user][token].lastIndex = globalReward[token].index;
        }
    }

    function _initGlobalReward(address[] memory rewardTokens) internal virtual {
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            if (globalReward[rewardTokens[i]].index == 0) {
                globalReward[rewardTokens[i]].index = INITIAL_REWARD_INDEX;
            }
        }
    }

    function _shouldUpdateGlobalReward() internal virtual returns (bool) {
        if (lastRewardUpdateBlock == block.number) {
            return false;
        }
        lastRewardUpdateBlock = block.number;
        return true;
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
