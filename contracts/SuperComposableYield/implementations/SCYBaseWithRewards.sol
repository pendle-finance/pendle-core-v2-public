// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.9;
import "../ISuperComposableYield.sol";
import "./RewardManager.sol";
import "./SCYBase.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../libraries/math/Math.sol";

/**
# CONDITIONS TO USE THIS PRESET:
- the token's balance must be static (i.e not increase on its own). Some examples of tokens don't
satisfy this restriction is AaveV2's aToken

*/
abstract contract SCYBaseWithRewards is SCYBase, RewardManager {
    using SafeERC20 for IERC20;
    using Math for uint256;

    event RedeemReward(address indexed user, uint256[] rewardsOut);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __scydecimals,
        uint8 __assetDecimals
    )
        SCYBase(_name, _symbol, __scydecimals, __assetDecimals)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function redeemReward(address user)
        external
        virtual
        override
        nonReentrant
        returns (uint256[] memory outAmounts)
    {
        _updateUserReward(user, balanceOf(user), totalSupply());
        outAmounts = _doTransferOutRewardsForUser(user, user);
        emit RedeemReward(user, outAmounts);
    }

    function updateGlobalReward() external virtual override {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, totalSupply());
    }

    function updateUserReward(address user) external virtual override {
        _updateUserReward(user, balanceOf(user), totalSupply());
    }

    function getRewardTokens()
        public
        view
        virtual
        override(ISuperComposableYield, RewardManager)
        returns (address[] memory);

    /*///////////////////////////////////////////////////////////////
                            TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /*amount*/
    ) internal virtual override {
        address[] memory rewardTokens = getRewardTokens();
        _updateGlobalReward(rewardTokens, totalSupply());
        if (from != address(0)) _updateUserRewardSkipGlobal(rewardTokens, from, balanceOf(from));
        if (to != address(0)) _updateUserRewardSkipGlobal(rewardTokens, to, balanceOf(to));
    }
}
