// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../interfaces/IRewardManager.sol";
import "./RewardManagerAbstract.sol";
import "./math/Math.sol";
import "../libraries/helpers/ArrayLib.sol";

/// * This RewardManager can be used with any contracts, regardless of what tokens that contract stores
/// since the RewardManager will maintain its own internal balance
/// * Use with SCY + PendleMarket. For YT, it has its own native implementation for gas saving
abstract contract RewardManager is RewardManagerAbstract {
    using Math for uint256;
    using ArrayLib for uint256[];

    uint256 public lastRewardBlock;

    mapping(address => RewardState) public rewardState;

    uint256 internal constant INITIAL_REWARD_INDEX = 1;

    function _updateRewardIndex()
        internal
        virtual
        override
        returns (address[] memory tokens, uint256[] memory indexes)
    {
        tokens = _getRewardTokens();

        if (lastRewardBlock != block.number) {
            // if we have not yet update the index for this block
            lastRewardBlock = block.number;

            uint256 totalShares = _rewardSharesTotal();

            uint256[] memory preBalances = _selfBalances(tokens);

            _redeemExternalReward();

            uint256[] memory accrued = _selfBalances(tokens).sub(preBalances);

            for (uint256 i = 0; i < tokens.length; ++i) {
                address token = tokens[i];
                uint256 index = rewardState[token].index;

                if (index == 0) index = INITIAL_REWARD_INDEX;
                if (totalShares != 0) index += accrued[i].divDown(totalShares);

                rewardState[token].index = index.Uint128();
                rewardState[token].lastBalance += accrued[i].Uint128();
            }
        }

        indexes = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) indexes[i] = rewardState[tokens[i]].index;
    }

    /// @dev this function doesn't need redeemExternal since redeemExternal is bundled in updateRewardIndex
    /// @dev this function also has to update rewardState.lastBalance
    function _doTransferOutRewards(address user, address receiver)
        internal
        virtual
        override
        returns (uint256[] memory rewardAmounts)
    {
        address[] memory tokens = _getRewardTokens();
        rewardAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            rewardAmounts[i] = userReward[tokens[i]][user].accrued;
            if (rewardAmounts[i] != 0) {
                userReward[tokens[i]][user].accrued = 0;
                rewardState[tokens[i]].lastBalance -= rewardAmounts[i].Uint128();
                _transferOut(tokens[i], receiver, rewardAmounts[i]);
            }
        }
    }
}
