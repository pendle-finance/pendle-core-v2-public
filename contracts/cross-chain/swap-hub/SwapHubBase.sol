// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {BoringOwnableUpgradeableV2} from "../../core/libraries/BoringOwnableUpgradeableV2.sol";
import {TokenHelper} from "../../core/libraries/TokenHelper.sol";
import {IPCrossChainSwapHub} from "../../interfaces/IPCrossChainSwapHub.sol";
import {IPDepositBox} from "../../interfaces/IPDepositBox.sol";
import {IPDepositBoxFactory} from "../../interfaces/IPDepositBoxFactory.sol";

abstract contract SwapHubBase is IPCrossChainSwapHub, EIP712Upgradeable, BoringOwnableUpgradeableV2, TokenHelper {
    // forgefmt: disable-next-item
    bytes32 internal constant BOX_PERMIT_TYPEHASH = keccak256(
        "BoxPermit("
            "address owner,"
            "uint32 boxId,"
            "uint256 expiry,"
            "uint256 requestId,"
            "uint256 nonce"
        ")"
    );

    // forgefmt: disable-next-item
    bytes32 internal constant WITHDRAW_TOKEN_MESSAGE_TYPEHASH = keccak256(
        "WithdrawTokenMessage("
            "BoxPermit permit,"
            "address token,"
            "uint256 amountWithdraw,"
            "uint256 amountFee"
        ")"
        "BoxPermit("
            "address owner,"
            "uint32 boxId,"
            "uint256 expiry,"
            "uint256 requestId,"
            "uint256 nonce"
        ")"
    );

    // forgefmt: disable-next-item
    bytes32 internal constant BRIDGE_TOKEN_MESSAGE_TYPEHASH = keccak256(
        "BridgeTokenMessage("
            "BoxPermit permit,"
            "address token,"
            "uint256 amountBridge,"
            "uint256 amountFee,"
            //
            "address bridgeExtRouter,"
            "address bridgeApprove,"
            "bytes bridgeCalldata"
        ")"
        "BoxPermit("
            "address owner,"
            "uint32 boxId,"
            "uint256 expiry,"
            "uint256 requestId,"
            "uint256 nonce"
        ")"
    );

    // forgefmt: disable-next-item
    bytes32 internal constant SWAP_TOKEN_MESSAGE_TYPEHASH = keccak256(
        "SwapTokenMessage("
            "BoxPermit permit,"
            "address tokenSpent,"
            "uint256 amountSpent,"
            "address tokenReceived,"
            "uint256 minReceived,"
            //
            "address swapExtRouter,"
            "address swapApprove,"
            "bytes swapCalldata"
        ")"
        "BoxPermit("
            "address owner,"
            "uint32 boxId,"
            "uint256 expiry,"
            "uint256 requestId,"
            "uint256 nonce"
        ")"
    );

    address public immutable TREASURY;
    IPDepositBoxFactory public immutable DEPOSIT_BOX_FACTORY;

    address public executor;
    address public proposer;
    mapping(uint256 requestId => uint256 nonce) public requestNonce;

    constructor(address treasury_, address depositBoxFactory_) {
        TREASURY = treasury_;
        DEPOSIT_BOX_FACTORY = IPDepositBoxFactory(depositBoxFactory_);
    }

    modifier onlyExecutor() {
        require(msg.sender == executor, Unauthorized());
        _;
    }

    function setExecutor(address executor_) external onlyOwner {
        executor = executor_;
        emit SetExecutor(executor);
    }

    function setProposer(address proposer_) external onlyOwner {
        proposer = proposer_;
        emit SetProposer(proposer);
    }

    function hashBoxPermit(BoxPermit memory permit) public pure returns (bytes32) {
        return keccak256(
            abi.encode(BOX_PERMIT_TYPEHASH, permit.owner, permit.boxId, permit.expiry, permit.requestId, permit.nonce)
        );
    }

    function hashTypedData(WithdrawTokenMessage memory ms) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    WITHDRAW_TOKEN_MESSAGE_TYPEHASH, hashBoxPermit(ms.permit), ms.token, ms.amountWithdraw, ms.amountFee
                )
            )
        );
    }

    function hashTypedData(BridgeTokenMessage memory ms) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    BRIDGE_TOKEN_MESSAGE_TYPEHASH,
                    hashBoxPermit(ms.permit),
                    ms.token,
                    ms.amountBridge,
                    ms.amountFee,
                    //
                    ms.bridgeExtRouter,
                    ms.bridgeApprove,
                    keccak256(ms.bridgeCalldata)
                )
            )
        );
    }

    function hashTypedData(SwapTokenMessage memory ms) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    SWAP_TOKEN_MESSAGE_TYPEHASH,
                    hashBoxPermit(ms.permit),
                    ms.tokenSpent,
                    ms.amountSpent,
                    ms.tokenReceived,
                    ms.minReceived,
                    //
                    ms.swapExtRouter,
                    ms.swapApprove,
                    keccak256(ms.swapCalldata)
                )
            )
        );
    }

    function _verifyProposerSig(
        uint256 expiry,
        uint256 requestId,
        uint256 nonce,
        bytes32 messageHash,
        bytes memory signature
    ) internal {
        require(expiry > block.timestamp, MessageExpired());
        require(SignatureChecker.isValidSignatureNow(proposer, messageHash, signature), InvalidSignature());
        require(requestNonce[requestId] == nonce, InvalidNonce());
        requestNonce[requestId] = nonce + 1;
    }

    function _checkBoxPermit(BoxPermit memory permit, bytes32 messageHash, bytes memory signature)
        internal
        returns (IPDepositBox)
    {
        _verifyProposerSig(permit.expiry, permit.requestId, permit.nonce, messageHash, signature);
        return DEPOSIT_BOX_FACTORY.deployDepositBox(permit.owner, permit.boxId);
    }
}
