// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPMerkleDistributor {
    event Claimed(address indexed user, address indexed receiver, uint256 amount);
    event Verified(address indexed user, uint256 amountClaimable);
    event SetMerkleRoot(bytes32 indexed merkleRoot);

    error InvalidMerkleProof();

    function claim(
        address receiver,
        uint256 totalAccrued,
        bytes32[] calldata proof
    ) external returns (uint256 amountOut);

    function claimVerified(address receiver) external returns (uint256 amountOut);

    function verify(
        address user,
        uint256 totalAccrued,
        bytes32[] calldata proof
    ) external returns (uint256 amountVerified);
}
