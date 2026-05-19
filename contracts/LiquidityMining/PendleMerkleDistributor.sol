// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../core/libraries/BoringOwnableUpgradeableV2.sol";
import "../core/libraries/TokenHelper.sol";
import "../interfaces/IPMerkleDistributor.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PendleMerkleDistributor is IPMerkleDistributor, UUPSUpgradeable, BoringOwnableUpgradeableV2, TokenHelper {
    address public immutable token;

    bytes32 public merkleRoot;

    mapping(address => uint256) public claimed;
    mapping(address => uint256) private __deprecated__verified;

    constructor(address _token) initializer {
        token = _token;
    }

    receive() external payable {}

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function claim(address receiver, uint256 totalAccrued, bytes32[] calldata proof)
        external
        returns (uint256 amountOut)
    {
        address user = msg.sender;
        if (!_verifyMerkleData(user, totalAccrued, proof)) revert InvalidMerkleProof();

        amountOut = totalAccrued - claimed[user];
        claimed[user] = totalAccrued;

        _transferOut(token, receiver, amountOut);
        emit Claimed(user, receiver, amountOut);
    }

    function _verifyMerkleData(address user, uint256 amount, bytes32[] calldata proof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    // ----------------- owner logic -----------------
    function setMerkleRoot(bytes32 newMerkleRoot) external payable onlyOwner {
        merkleRoot = newMerkleRoot;
        emit SetMerkleRoot(merkleRoot);
    }

    // ----------------- upgrade-related -----------------

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
