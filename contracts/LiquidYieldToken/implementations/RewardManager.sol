// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
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
        uint256 accruedReward;
    }

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    uint256 public immutable rewardLength;

    GlobalReward[] public globalReward;
    mapping(address => UserReward[]) public userReward;

    constructor(uint256 _rewardLength) {
        rewardLength = _rewardLength;
        for (uint256 i = 0; i < rewardLength; i++) {
            globalReward.push(GlobalReward(INITIAL_REWARD_INDEX, 0));
        }
    }

    function _doTransferOutRewards(address user)
        internal
        virtual
        returns (uint256[] memory outAmounts)
    {
        outAmounts = new uint256[](rewardLength);

        address[] memory rewardTokens = getRewardTokens();
        for (uint256 i = 0; i < rewardLength; ++i) {
            IERC20 token = IERC20(rewardTokens[i]);

            outAmounts[i] = userReward[user][i].accruedReward;
            userReward[user][i].accruedReward = 0;

            globalReward[i].lastBalance -= outAmounts[i];

            if (outAmounts[i] != 0) {
                token.safeTransfer(user, outAmounts[i]);
            }
        }
    }

    function _updateUserReward(
        address user,
        uint256 balanceOfUser,
        uint256 totalSupply
    ) internal virtual {
        _updateGlobalReward(totalSupply);
        _updateUserRewardSkipGlobal(user, balanceOfUser);
    }

    function _updateGlobalReward(uint256 totalSupply) internal virtual {
        _redeemExternalReward();

        address[] memory rewardTokens = getRewardTokens();
        for (uint256 i = 0; i < rewardLength; ++i) {
            IERC20 token = IERC20(rewardTokens[i]);

            uint256 currentRewardBalance = token.balanceOf(address(this));

            if (totalSupply != 0) {
                globalReward[i].index += (currentRewardBalance - globalReward[i].lastBalance)
                    .divDown(totalSupply);
            }

            globalReward[i].lastBalance = currentRewardBalance;
        }
    }

    function _updateUserRewardSkipGlobal(address user, uint256 balanceOfUser) internal virtual {
        for (uint256 i = 0; i < rewardLength; ++i) {
            uint256 userLastIndex = userReward[user][i].lastIndex;
            if (userLastIndex == globalReward[i].index) continue;

            uint256 rewardAmountPerUnit = globalReward[i].index - userLastIndex;
            uint256 rewardFromUnit = balanceOfUser.mulDown(rewardAmountPerUnit);

            userReward[user][i].accruedReward += rewardFromUnit;
            userReward[user][i].lastIndex = globalReward[i].index;
        }
    }

    function getRewardTokens() public view virtual returns (address[] memory);

    function _redeemExternalReward() internal virtual;
}
