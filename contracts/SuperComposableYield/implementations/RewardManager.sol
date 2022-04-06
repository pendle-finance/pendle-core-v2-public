// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../ISuperComposableYield.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../libraries/math/FixedPoint.sol";

abstract contract RewardManager {
    using SafeERC20 for IERC20;
    using FixedPoint for uint256;

    struct GlobalReward {
        uint256 index;
        uint256 lastBalance;
    }

    struct UserReward {
        uint256 lastIndex;
        uint256 accuredReward;
    }

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    mapping(address => GlobalReward) public globalReward;
    mapping(address => mapping(address => UserReward)) public userReward;

    function _doTransferOutRewardsForUser(address user)
        internal
        virtual
        returns (uint256[] memory outAmounts)
    {
        address[] memory rewardTokens = getRewardTokens();

        outAmounts = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            outAmounts[i] = userReward[user][token].accuredReward;
            userReward[user][token].accuredReward = 0;

            globalReward[token].lastBalance -= outAmounts[i];

            if (outAmounts[i] != 0) {
                IERC20(token).safeTransfer(user, outAmounts[i]);
            }
        }
    }

    function _updateUserReward(
        address user,
        uint256 balanceOfUser,
        uint256 totalSupply
    ) internal virtual {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, totalSupply);
        _updateUserRewardSkipGlobal(rewardTokens, user, balanceOfUser);
    }

    function _updateGlobalReward(address[] memory rewardTokens, uint256 totalSupply)
        internal
        virtual
    {
        _redeemExternalReward();

        _initGlobalReward(rewardTokens);

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 currentRewardBalance = IERC20(token).balanceOf(address(this));

            if (totalSupply != 0) {
                globalReward[token].index += (currentRewardBalance -
                    globalReward[token].lastBalance).divDown(totalSupply);
            }

            globalReward[token].lastBalance = currentRewardBalance;
        }
    }

    function _updateUserRewardSkipGlobal(
        address[] memory rewardTokens,
        address user,
        uint256 balanceOfUser
    ) internal virtual {
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];

            uint256 userLastIndex = userReward[user][token].lastIndex;
            if (userLastIndex == 0) {
                // first time receiving this reward
                userReward[user][token].lastIndex = globalReward[token].index;
                continue;
            }
            if (userLastIndex == globalReward[token].index) continue;

            uint256 rewardAmountPerUnit = globalReward[token].index - userLastIndex;
            uint256 rewardFromUnit = balanceOfUser.mulDown(rewardAmountPerUnit);

            userReward[user][token].accuredReward += rewardFromUnit;
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

    function getRewardTokens() public view virtual returns (address[] memory);

    function _redeemExternalReward() internal virtual;
}
