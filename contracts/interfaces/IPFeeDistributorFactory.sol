// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPFeeDistributorFactory {
    function lastFinishedEpoch() external returns (uint256);

    function updateUserShare(address user, address pool) external;

    function getUserAndTotalSharesAt(
        address user,
        address pool,
        uint256 epoch
    ) external view returns (uint256 userShare, uint256 totalShare);
}
