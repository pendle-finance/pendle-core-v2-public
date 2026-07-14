// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";
import {TokenHelper} from "../core/libraries/TokenHelper.sol";
import {IMoneyMarket} from "../interfaces/IMoneyMarket.sol";
import {BoxData, IPLoopPositionBox} from "../interfaces/IPLoopPositionBox.sol";
import {IPLoopPositionBoxFactory} from "../interfaces/IPLoopPositionBoxFactory.sol";
import {IPPTLooper} from "../interfaces/IPPTLooper.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {PTLooperEIP712TypesEncodeDataLib} from "./PTLooperEIP712TypesEncodeDataLib.sol";

abstract contract PTLooperBase is IPPTLooper, EIP712Upgradeable, BoringOwnableUpgradeableV2, TokenHelper {
    using PTLooperEIP712TypesEncodeDataLib for *;

    address public immutable TREASURY;
    IPLoopPositionBoxFactory public immutable POSITION_BOX_FACTORY;

    address public executor;
    address public proposer;
    mapping(address owner => mapping(bytes32 requestHash => uint256 nonce)) public proposerNonce;
    mapping(address owner => mapping(bytes32 boxId => UserRequestInfo)) internal _userRequest;

    constructor(address treasury_, address positionBoxFactory_) {
        TREASURY = treasury_;
        POSITION_BOX_FACTORY = IPLoopPositionBoxFactory(positionBoxFactory_);
    }

    function userRequest(address owner, bytes32 boxId) external view returns (UserRequestInfo memory) {
        return _userRequest[owner][boxId];
    }

    modifier onlyExecutor() {
        require(msg.sender == executor, "PTLooper: unauthorized");
        _;
    }

    modifier onlyExecutorOrBoxOwner(address boxOwner) {
        require(msg.sender == executor || msg.sender == boxOwner, "PTLooper: unauthorized");
        _;
    }

    function setExecutor(address executor_) external onlyOwner {
        executor = executor_;
        emit SetExecutor(executor_);
    }

    function setProposer(address proposer_) external onlyOwner {
        proposer = proposer_;
        emit SetProposer(proposer_);
    }

    // ========== Hash functions ==========

    function hashRaw(BoxPermit memory permit) public pure returns (bytes32) {
        return permit.encodeData();
    }

    function hashRaw(RequestHeader memory header) public pure returns (bytes32) {
        return header.encodeData();
    }

    function hashRaw(BoxApprovedCall memory call) public pure returns (bytes32) {
        return call.encodeData();
    }

    function hashRaw(BridgeData memory bridge) public pure returns (bytes32) {
        return bridge.encodeData();
    }

    function hashRaw(IncreasePositionRequest memory req) public pure returns (bytes32) {
        return req.encodeData();
    }

    function hashRaw(DecreasePositionRequest memory req) public pure returns (bytes32) {
        return req.encodeData();
    }

    function hashRaw(SwapBridgeWithdrawAllRequest memory req) public pure returns (bytes32) {
        return req.encodeData();
    }

    function hashRaw(ClaimMMRewardsRequest memory req) public pure returns (bytes32) {
        return req.encodeData();
    }

    function hashRaw(ClaimMMRewardsMessage memory ms) public pure returns (bytes32) {
        return ms.encodeData();
    }

    function hashTyped(IncreasePositionRequest memory req) public view returns (bytes32) {
        return _hashTypedDataV4(req.encodeData());
    }

    function hashTyped(IncreasePositionMessage memory ms) public view returns (bytes32) {
        return _hashTypedDataV4(ms.encodeData());
    }

    function hashTyped(DecreasePositionRequest memory req) public view returns (bytes32) {
        return _hashTypedDataV4(req.encodeData());
    }

    function hashTyped(DecreasePositionMessage memory ms) public view returns (bytes32) {
        return _hashTypedDataV4(ms.encodeData());
    }

    function hashTyped(SwapBridgeWithdrawAllRequest memory req) public view returns (bytes32) {
        return _hashTypedDataV4(req.encodeData());
    }

    function hashTyped(SwapBridgeWithdrawAllMessage memory ms) public view returns (bytes32) {
        return _hashTypedDataV4(ms.encodeData());
    }

    function hashTyped(ClaimMMRewardsRequest memory req) public view returns (bytes32) {
        return _hashTypedDataV4(req.encodeData());
    }

    function hashTyped(ClaimMMRewardsMessage memory ms) public view returns (bytes32) {
        return _hashTypedDataV4(ms.encodeData());
    }

    /// @dev Per-iteration ctx returned by `_ensureSessionAndAuth`. `spokeMM` is unread on the
    /// swap-bridge-withdraw path but always populated — splitting per entry point would cost
    /// more bytecode than it saves. On chains that are neither hub nor spoke for the box,
    /// `spokeMM` is `address(0)`; downstream calls to it then revert at the EVM level (zero-
    /// address call) — that implicit check replaces an explicit chain-id assert. Note: paths that
    /// resolve the debt token via `PendlePTLooper._debtTokenHere` instead get an explicit
    /// "PTLooper: unsupported chainid" revert before any `spokeMM` use.
    struct Session {
        IPLoopPositionBox box;
        IMoneyMarket spokeMM;
        BoxData bd;
    }

    function _ensureSessionAndAuth(
        IncreasePositionMessage memory ms,
        IncreasePositionRequest memory req,
        bytes memory proposerSig,
        bytes memory ownerSigIfFirstCall
    ) internal returns (Session memory s, bytes32 requestHash) {
        requestHash = hashTyped(req);
        s = _ensureSessionAndAuthCore(
            ms.permit, req.header, hashTyped(ms), proposerSig, requestHash, ownerSigIfFirstCall
        );
    }

    function _ensureSessionAndAuth(
        DecreasePositionMessage memory ms,
        DecreasePositionRequest memory req,
        bytes memory proposerSig,
        bytes memory ownerSigIfFirstCall
    ) internal returns (Session memory s, bytes32 requestHash) {
        requestHash = hashTyped(req);
        s = _ensureSessionAndAuthCore(
            ms.permit, req.header, hashTyped(ms), proposerSig, requestHash, ownerSigIfFirstCall
        );
    }

    function _ensureSessionAndAuth(
        SwapBridgeWithdrawAllMessage memory ms,
        SwapBridgeWithdrawAllRequest memory req,
        bytes memory proposerSig,
        bytes memory ownerSigIfFirstCall
    ) internal returns (Session memory s, bytes32 requestHash) {
        requestHash = hashTyped(req);
        s = _ensureSessionAndAuthCore(
            ms.permit, req.header, hashTyped(ms), proposerSig, requestHash, ownerSigIfFirstCall
        );
    }

    function _ensureSessionAndAuth(
        ClaimMMRewardsMessage memory ms,
        ClaimMMRewardsRequest memory req,
        bytes memory proposerSig,
        bytes memory ownerSigIfFirstCall
    ) internal returns (Session memory s, bytes32 requestHash) {
        requestHash = hashTyped(req);
        s = _ensureSessionAndAuthCore(
            ms.permit, req.header, hashTyped(ms), proposerSig, requestHash, ownerSigIfFirstCall
        );
    }

    /// @dev Per-iteration auth + implicit session init. First call for a slot
    /// (`userReq.requestHash == 0`) opens the session — checks `boxId`/`sessionNonce` agree and
    /// verifies the owner sig. Subsequent calls just match `userReq.requestHash`;
    /// `ownerSigIfFirstCall` is ignored. Proposer auth runs in both branches; the per-iteration
    /// nonce slot is keyed by `(owner, requestHash)` so distinct sessions or owners never share
    /// a counter.
    function _ensureSessionAndAuthCore(
        BoxPermit memory permit,
        RequestHeader memory header,
        bytes32 msgHash,
        bytes memory proposerSig,
        bytes32 requestHash,
        bytes memory ownerSigIfFirstCall
    ) private returns (Session memory s) {
        UserRequestInfo storage userReq = _userRequest[permit.owner][permit.boxId];

        // Expiry checked before the `requestHash` write below (CEI).
        require(header.expiry > block.timestamp, "PTLooper: request expired"); // forge-lint: disable-line(block-timestamp)

        if (userReq.requestHash == bytes32(0)) {
            // First call for this slot — implicit session init.
            require(header.boxId == permit.boxId, "PTLooper: req/permit boxId mismatch");
            require(header.sessionNonce == userReq.sessionNonce, "PTLooper: invalid session nonce");
            require(
                SignatureChecker.isValidSignatureNow(permit.owner, requestHash, ownerSigIfFirstCall),
                "PTLooper: invalid owner signature"
            );
            userReq.requestHash = requestHash;
            emit SessionInitiated(permit.owner, permit.boxId, requestHash, userReq.sessionNonce);
        } else {
            require(userReq.requestHash == requestHash, "PTLooper: request hash mismatch");
        }

        return _authPermit(permit, msgHash, proposerSig, header.permitNonceCap, requestHash);
    }

    function _authPermit(
        BoxPermit memory permit,
        bytes32 msgHash,
        bytes memory proposerSig,
        uint256 permitNonceCap,
        bytes32 requestHash
    ) private returns (Session memory s) {
        require(permit.expiry > block.timestamp, "PTLooper: message expired"); // forge-lint: disable-line(block-timestamp)
        require(SignatureChecker.isValidSignatureNow(proposer, msgHash, proposerSig), "PTLooper: invalid signature");
        require(permit.nonce < permitNonceCap, "PTLooper: permitNonceCap exceeded");
        require(proposerNonce[permit.owner][requestHash] == permit.nonce, "PTLooper: invalid proposer nonce");
        proposerNonce[permit.owner][requestHash] = permit.nonce + 1;

        (s.box, s.spokeMM, s.bd) = POSITION_BOX_FACTORY.deployPositionBoxAndMoneyMarket(permit.owner, permit.boxId);
    }
}
