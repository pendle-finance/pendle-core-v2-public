// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "../ILiquidYieldToken.sol";
import "./RewardManager.sol";
import "./LYTBase.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../../libraries/math/FixedPoint.sol";

/**
# CONDITIONS TO USE THIS PRESET:
- the token's balance must be static (i.e not increase on its own). Some examples of tokens don't
satisfy this restriction is AaveV2's aToken

*/
abstract contract LYTBaseWithRewards is LYTBase, RewardManager {
    using SafeERC20 for IERC20;
    using FixedPoint for uint256;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        uint256 _rewardLength
    )
        LYTBase(_name, _symbol, __lytdecimals, __assetDecimals)
        RewardManager(_rewardLength)
    // solhint-disable-next-line no-empty-blocks
    {

    }

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    function redeemReward(address user)
        public
        virtual
        override
        returns (uint256[] memory outAmounts)
    {
        _updateUserReward(user, balanceOf(user), totalSupply());
        outAmounts = _doTransferOutRewards(user);
    }

    function updateGlobalReward() public virtual override {
        _updateGlobalReward(totalSupply());
    }

    function updateUserReward(address user) public virtual override {
        _updateUserReward(user, balanceOf(user), totalSupply());
    }

    function getRewardTokens()
        public
        view
        virtual
        override(ILiquidYieldToken, RewardManager)
        returns (address[] memory);

    /*///////////////////////////////////////////////////////////////
                            TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /*amount*/
    ) internal virtual override {
        _updateGlobalReward(totalSupply());
        if (from != address(0)) _updateUserRewardSkipGlobal(from, balanceOf(from));
        if (to != address(0)) _updateUserRewardSkipGlobal(to, balanceOf(to));
    }
}
