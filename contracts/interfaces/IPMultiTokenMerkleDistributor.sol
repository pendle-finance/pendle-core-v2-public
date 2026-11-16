// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPMultiTokenMerkleDistributor {
    event Claimed(address indexed token, address indexed user, address indexed receiver, uint256 amount);
    event SetMerkleRoot(bytes32 indexed merkleRoot);
    event SetSetter(address indexed setter);
    event Withdrawn(address indexed token, address indexed receiver, uint256 amount);

    error InvalidMerkleProof();
    error NotOwnerOrSetter();

    function merkleRoot() external view returns (bytes32);

    function setter() external view returns (address);

    function claimed(address token, address user) external view returns (uint256);

    function claim(address receiver, address[] memory tokens, uint256[] memory totalAccrueds, bytes32[][] memory proofs)
        external
        returns (uint256[] memory amountOuts);

    function setMerkleRoot(bytes32 newMerkleRoot) external payable;

    function setSetter(address newSetter) external;

    function withdraw(address[] calldata tokens, address[] calldata receivers, uint256[] calldata amounts) external;
}
