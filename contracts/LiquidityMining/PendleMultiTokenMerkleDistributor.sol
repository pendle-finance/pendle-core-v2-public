// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "../core/libraries/BoringOwnableUpgradeableV2.sol";
import "../core/libraries/Errors.sol";
import "../core/libraries/TokenHelper.sol";
import "../interfaces/IPMultiTokenMerkleDistributor.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PendleMultiTokenMerkleDistributor is
    IPMultiTokenMerkleDistributor,
    UUPSUpgradeable,
    BoringOwnableUpgradeableV2,
    TokenHelper
{
    bytes32 public merkleRoot;

    /// (token, user) => amount
    mapping(address => mapping(address => uint256)) public claimed;
    mapping(address => mapping(address => uint256)) private __deprecated__verified;

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize(address _owner) external initializer {
        __BoringOwnableV2_init(_owner);
    }

    function claim(address receiver, address[] memory tokens, uint256[] memory totalAccrueds, bytes32[][] memory proofs)
        external
        returns (uint256[] memory amountOuts)
    {
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

    function _verifyMerkleData(address token, address user, uint256 amount, bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
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
