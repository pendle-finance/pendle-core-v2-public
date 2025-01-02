// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../core/libraries/TokenHelper.sol";
import "../core/libraries/Errors.sol";
import "../interfaces/IPMultiTokenMerkleDistributor.sol";

contract PendleMultiTokenMerkleDistributor is
    IPMultiTokenMerkleDistributor,
    UUPSUpgradeable,
    BoringOwnableUpgradeable,
    TokenHelper
{
    bytes32 public merkleRoot;

    /// (token, user) => amount
    mapping(address => mapping(address => uint256)) public claimed;
    mapping(address => mapping(address => uint256)) public verified;

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize() external initializer {
        __BoringOwnable_init();
    }

    function claim(
        address receiver,
        address[] memory tokens,
        uint256[] memory totalAccrueds,
        bytes32[][] memory proofs
    ) external returns (uint256[] memory amountOuts) {
        if (tokens.length != totalAccrueds.length || tokens.length != proofs.length) {
            revert Errors.ArrayLengthMismatch();
        }

        address user = msg.sender;
        uint256 nToken = tokens.length;
        amountOuts = new uint256[](nToken);

        for (uint256 i = 0; i < nToken; ++i) {
            (address token, uint256 totalAccrued, bytes32[] memory proof) = (tokens[i], totalAccrueds[i], proofs[i]);
            if (!_verifyMerkleData(token, user, totalAccrued, proof)) revert InvalidMerkleProof();

            amountOuts[i] = totalAccrued - claimed[token][user];
            claimed[token][user] = totalAccrued;

            _transferOut(token, receiver, amountOuts[i]);
            emit Claimed(token, user, receiver, amountOuts[i]);
        }
    }

    function claimVerified(address receiver, address[] memory tokens) external returns (uint256[] memory amountOuts) {
        address user = msg.sender;
        uint256 nToken = tokens.length;
        amountOuts = new uint256[](nToken);

        for (uint256 i = 0; i < nToken; ++i) {
            address token = tokens[i];
            uint256 amountVerified = verified[token][user];
            uint256 amountClaimed = claimed[token][user];

            if (amountVerified > amountClaimed) {
                amountOuts[i] = amountVerified - amountClaimed;
                claimed[token][user] = amountVerified;
                _transferOut(token, receiver, amountOuts[i]);
                emit Claimed(token, user, receiver, amountOuts[i]);
            }
        }
    }

    function verify(
        address user,
        address[] memory tokens,
        uint256[] memory totalAccrueds,
        bytes32[][] memory proofs
    ) external returns (uint256[] memory amountClaimable) {
        uint256 nToken = tokens.length;
        amountClaimable = new uint256[](nToken);

        for (uint256 i = 0; i < nToken; ++i) {
            (address token, uint256 totalAccrued, bytes32[] memory proof) = (tokens[i], totalAccrueds[i], proofs[i]);
            if (!_verifyMerkleData(token, user, totalAccrued, proof)) revert InvalidMerkleProof();
            amountClaimable[i] = totalAccrued - claimed[token][user];
            verified[token][user] = totalAccrued;
            emit Verified(token, user, amountClaimable[i]);
        }
    }

    function _verifyMerkleData(
        address token,
        address user,
        uint256 amount,
        bytes32[] memory proof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(token, user, amount));
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
