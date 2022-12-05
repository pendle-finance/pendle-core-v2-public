// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./SYBase.sol";

/**
 * @dev SYBaseAutoCompound aims to support staking asset that has itself as
 * the rewardToken
 * 
 * @notice Unlike usual sy - taking exchangeRate from underlying protocol, 
 * this variant of SY should account for its own exchangeRate
 */
abstract contract SYBaseAutoCompound is SYBase {
    using Math for uint256;

    constructor(
        string memory _name,
        string memory _symbol,
        address _asset
    )
        SYBase(_name, _symbol, _asset) // solhint-disable-next-line no-empty-blocks
    {}

    /**
     * @notice 
     */
    function exchangeRate() public view virtual override returns (uint256) {
        return getTotalAssetOwned().divDown(totalSupply());
    }

    /**
     * @return totalAssetOwned the total asset owned by SY contract
     * @notice This should includes:
     * 1. Staked Asset
     * 2. Floating asset reward (might be permissionlessly claimed)
     * 3. Unclaimed asset reward
     */
    function getTotalAssetOwned() public view virtual returns (uint256 totalAssetOwned);

    function _claimRewardsAndCompoundAsset() internal virtual;
}
