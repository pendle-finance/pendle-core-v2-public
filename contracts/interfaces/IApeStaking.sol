// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IApeStaking {
    function apeCoin() external view returns (address);

    function depositSelfApeCoin(uint256 _amount) external;

    function withdrawApeCoin(uint256 _amount, address _recipient) external;

    function claimSelfApeCoin() external;

    /**
     * @notice when poolId is set to 0, tokenId's value does not matter
     */
    function pendingRewards(uint256 _poolId, address _address, uint256 _tokenId) external view returns (uint256);

    function addressPosition(address addr) external view returns (uint256 stakedAmount, int256 rewardsDebt);

    // for SDK
    function pools(uint256 id) external view returns (uint48, uint16, uint96 totalStaked, uint96);
}
