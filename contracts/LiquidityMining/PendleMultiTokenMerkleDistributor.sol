// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../core/libraries/BoringOwnableUpgradeable.sol";
import "../core/libraries/TokenHelper.sol";
import "../interfaces/IPMultiTokenMerkleDistributor.sol";

contract PendleMultiMerkleDistributor is
    IPMultiTokenMerkleDistributor,
    UUPSUpgradeable,
    BoringOwnableUpgradeable,
    TokenHelper
{
    bytes32 public merkleRoot;

    /// (token, user) => amount
    mapping(address => mapping(address => uint256)) public claimed;
    mapping(address => mapping(address => uint256)) public verified;

    address[] public defaultTokenList;

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize(address[] calldata _initialDefaultTokenList) external initializer {
        __BoringOwnable_init();
        _setDefaultTokenList(_initialDefaultTokenList);
    }

    function getRewardTokenList() external view returns (address[] memory) {
        return defaultTokenList;
    }

    function claim(
        address[] memory tokens,
        address[] memory receivers,
        uint256[] memory totalAccrueds,
        bytes32[][] memory proofs
    ) external returns (uint256[] memory amountOuts) {
        address user = msg.sender;
        uint256 nToken = tokens.length;
        amountOuts = new uint256[](nToken);

        for (uint256 i = 0; i < nToken; ++i) {
            (address token, address receiver, uint256 totalAccrued, bytes32[] memory proof) = (
                tokens[i],
                receivers[i],
                totalAccrueds[i],
                proofs[i]
            );
            if (!_verifyMerkleData(token, user, totalAccrued, proof)) revert InvalidMerkleProof();

            amountOuts[i] = totalAccrued - claimed[token][user];
            claimed[token][user] = totalAccrued;

            _transferOut(token, receiver, amountOuts[i]);
            emit Claimed(token, user, receiver, amountOuts[i]);
        }
    }

    function claimVerified(address[] memory tokens, address receiver) external returns (uint256[] memory amountOuts) {
        address user = msg.sender;
        uint256 nToken = tokens.length;

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

    function setDefaultTokenList(address[] memory _newDefaultTokenList) external onlyOwner {
        _setDefaultTokenList(_newDefaultTokenList);
    }

    function _setDefaultTokenList(address[] memory _newDefaultTokenList) internal {
        defaultTokenList = _newDefaultTokenList;
        emit SetDefaultTokenList(_newDefaultTokenList);
    }

    // ----------------- upgrade-related -----------------

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
