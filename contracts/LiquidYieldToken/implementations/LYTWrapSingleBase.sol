// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "./LYTWrapSingleBaseWithRewards.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../../libraries/math/FixedPoint.sol";

/**
# CONDITIONS TO USE THIS PRESET:
- the token's balance must be static (i.e not increase on its own). Some examples of tokens don't
satisfy this restriction is AaveV2's aToken

# OVERVIEW OF THIS PRESET
- 1 unit of YieldToken is wrapped into 1 unit of LYT
*/
abstract contract LYTWrapSingleBase is LYTWrapSingleBaseWithRewards {
    using SafeERC20 for IERC20;
    using FixedPoint for uint256;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 __lytdecimals,
        uint8 __assetDecimals,
        address _baseToken,
        address _yieldToken
    )
        LYTWrapSingleBaseWithRewards(
            _name,
            _symbol,
            __lytdecimals,
            __assetDecimals,
            _baseToken,
            _yieldToken,
            0
        ) //solhint-disable-next-line no-empty-blocks
    {}

    /*///////////////////////////////////////////////////////////////
                               REWARDS-RELATED
    //////////////////////////////////////////////////////////////*/

    //solhint-disable-next-line no-empty-blocks
    function redeemReward() public override returns (uint256[] memory outAmounts) {}

    //solhint-disable-next-line no-empty-blocks
    function updateGlobalReward() public override {}

    //solhint-disable-next-line no-empty-blocks
    function updateUserReward(address user) public override {}

    ///@dev this function must match with the _getRewardToken
    function getRewardTokens() public view virtual override returns (address[] memory res) {
        res = new address[](0);
    }

    /*///////////////////////////////////////////////////////////////
                            TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/
    function _beforeTokenTransfer(
        address,
        address,
        uint256 //solhint-disable-next-line no-empty-blocks
    ) internal virtual override {}
}
