// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPFeeDistributorV2 {
    event SetMerkleRootAndFund(bytes32 indexed merkleRoot, uint256 amountFunded);

    event Claimed(address indexed user, uint256 amountOut);

    event UpdateProtocolClaimable(address indexed user, uint256 sumTopUp);

    struct UpdateProtocolStruct {
        address user;
        bytes32[] proof;
        address[] pools;
        uint256[] topUps;
    }

    /**
     * @notice submit total ETH accrued & proof to claim the outstanding amount. Intended to be
     used by retail users
     */
    function claimRetail(
        address receiver,
        uint256 totalAccrued,
        bytes32[] calldata proof
    ) external returns (uint256 amountOut);

    /**
     * @notice Protocols that require the use of this function & feeData should contact the Pendle team.
     * @notice Protocols should NOT EVER use claimRetail. Using it will make getProtocolFeeData unreliable.
     */
    function claimProtocol(
        address receiver,
        address[] calldata pools
    ) external returns (uint256 totalAmountOut, uint256[] memory amountsOut);

    /**
    * @notice returns the claimable fees per pool. Only available if the Pendle team has specifically
    set up the data
     */
    function getProtocolClaimables(
        address user,
        address[] calldata pools
    ) external view returns (uint256[] memory claimables);

    function getProtocolTotalAccrued(address user) external view returns (uint256);
}
