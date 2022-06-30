// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../../interfaces/ISuperComposableYield.sol";
import "../../libraries/RewardManager.sol";
import "./SCYBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../libraries/math/Math.sol";

/// This contract makes an important assumption that yieldToken is never a rewardToken
/// Please make sure that assumption always holds
abstract contract SCYBaseWithRewards is SCYBase, RewardManager {
    using Math for uint256;
    using ArrayLib for address[];

    constructor(
        string memory _name,
        string memory _symbol,
        address _yieldToken
    )
        SCYBase(_name, _symbol, _yieldToken) // solhint-disable-next-line no-empty-blocks
    {}

    function _getFloatingAmount(address token) internal view virtual override returns (uint256) {
        // there are only 2 type of tokens stored in the contract: yieldToken & rewardToken. Since
        // this is not yield, it must be reward
        if (token != yieldToken) return _selfBalance(token) - rewardState[token].lastBalance;
        return _selfBalance(token) - yieldTokenReserve;
    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev See {ISuperComposableYield-claimRewards}
     */
    function claimRewards(address user)
        external
        virtual
        override
        nonReentrant
        returns (uint256[] memory rewardAmounts)
    {
        _updateAndDistributeRewards(user);
        rewardAmounts = _doTransferOutRewards(user, user);

        emit ClaimRewards(user, _getRewardTokens(), rewardAmounts);
    }

    /**
     * @dev See {ISuperComposableYield-getRewardTokens}
     */
    function getRewardTokens()
        external
        view
        virtual
        override
        returns (address[] memory rewardTokens)
    {
        rewardTokens = _getRewardTokens();
    }

    /**
     * @dev See {ISuperComposableYield-accruedRewards}
     */
    function accruedRewards(address user)
        external
        view
        virtual
        override
        returns (uint256[] memory rewardAmounts)
    {
        address[] memory rewardTokens = _getRewardTokens();
        rewardAmounts = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ) {
            rewardAmounts[i] = userReward[user][rewardTokens[i]].accrued;
            unchecked {
                i++;
            }
        }
    }

    function rewardIndexesCurrent() external override returns (uint256[] memory indexes) {
        _updateRewardIndex();
        return rewardIndexesStored();
    }

    function rewardIndexesStored()
        public
        view
        virtual
        override
        returns (uint256[] memory indexes)
    {
        address[] memory rewardTokens = _getRewardTokens();
        indexes = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; ) {
            indexes[i] = rewardState[rewardTokens[i]].index;
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice returns the total number of reward shares
     * @dev this is simply the total supply of shares, as rewards shares are equivalent to SCY shares
     */
    function _rewardSharesTotal() internal view virtual override returns (uint256) {
        return totalSupply();
    }

    /**
     * @notice returns the reward shares of (`user`)
     * @dev this is simply the SCY balance of (`user`), as rewards shares are equivalent to SCY shares
     */
    function _rewardSharesUser(address user) internal view virtual override returns (uint256) {
        return balanceOf(user);
    }

    /*///////////////////////////////////////////////////////////////
                            TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal virtual override {
        _updateAndDistributeRewardsForTwo(from, to);
    }
}
