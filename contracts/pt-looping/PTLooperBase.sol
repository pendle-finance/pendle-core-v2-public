// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.30;

import {BoringOwnableUpgradeableV2} from "../core/libraries/BoringOwnableUpgradeableV2.sol";
import {TokenHelper} from "../core/libraries/TokenHelper.sol";
import {IMoneyMarket, MarketCtx, createMarketCtx} from "../interfaces/IMoneyMarket.sol";
import {BoxData, IPLoopPositionBox} from "../interfaces/IPLoopPositionBox.sol";
import {IPLoopPositionBoxFactory} from "../interfaces/IPLoopPositionBoxFactory.sol";
import {IPPTLooper} from "../interfaces/IPPTLooper.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {PTLooperEIP712TypesEncodeDataLib} from "./PTLooperEIP712TypesEncodeDataLib.sol";

abstract contract PTLooperBase is IPPTLooper, EIP712Upgradeable, BoringOwnableUpgradeableV2, TokenHelper {
    using PTLooperEIP712TypesEncodeDataLib for *;

    address public immutable TREASURY;
    IPLoopPositionBoxFactory public immutable POSITION_BOX_FACTORY;

    /// @dev The implementation. `execute` delegatecalls it directly, skipping the proxy.
    address private immutable _SELF = address(this);

    /// @dev True while `execute` runs the calls.
    bool private transient _executing;

    /// @dev Hash of the one `flashIncrease` / `flashDecrease` call that the box may make inside a flash loan.
    bytes32 internal transient _flashCallHash;

    address public executor;
    address public checker;

    /// @dev Unused. Kept for the proxy storage layout.
    mapping(address owner => mapping(bytes32 requestHash => uint256 nonce)) private __deprecatedProposerNonce;
    /// @dev Unused. Kept for the proxy storage layout. The value type is a placeholder.
    mapping(address owner => mapping(bytes32 boxId => bytes32)) private __deprecatedUserRequest;
    mapping(address owner => mapping(bytes32 requestHash => RequestStatus)) public requestStatus;

    constructor(address treasury_, address positionBoxFactory_) {
        TREASURY = treasury_;
        POSITION_BOX_FACTORY = IPLoopPositionBoxFactory(positionBoxFactory_);
    }

    // ========== Execute ==========
    //
    // Each call is a delegatecall into the implementation, so `msg.sender` stays the executor.
    // `onlyExecutor` passes only in `execute`; a router or box callback reverts, as its `msg.sender` is not
    // the executor.

    /// @dev A transaction never has a zero `tx.origin`, so the checks are skipped only in a simulation.
    function execute(Execution memory execution, bytes calldata checkerSig) external returns (bytes[] memory results) {
        if (tx.origin != address(0)) {
            require(msg.sender == executor, "PTLooper: unauthorized");
            require(executor.code.length == 0, "PTLooper: non-EOA executor");
            require(checker.code.length == 0, "PTLooper: non-EOA checker");
            require(execution.deadline >= block.timestamp, "PTLooper: execution expired"); // forge-lint: disable-line(block-timestamp)
            require(
                SignatureChecker.isValidSignatureNow(checker, _hashExecution(execution), checkerSig),
                "PTLooper: invalid signature"
            );
        }

        bytes[] memory calls = execution.calls;
        results = new bytes[](calls.length);

        _executing = true;
        for (uint256 i = 0; i < calls.length; ++i) {
            results[i] = Address.functionDelegateCall(_SELF, calls[i]);
        }
        _executing = false;
    }

    /// @dev A simulation (`tx.origin == 0`) passes with any caller.
    function _checkExecutor() internal view {
        require(_executing && (msg.sender == executor || tx.origin == address(0)), "PTLooper: unauthorized");
    }

    modifier onlyExecutor() {
        _checkExecutor();
        _;
    }

    modifier onlyExecutorOrBoxOwner(address boxOwner) {
        if (msg.sender != boxOwner) _checkExecutor();
        _;
    }

    function setExecutor(address executor_) external onlyOwner {
        executor = executor_;
        emit SetExecutor(executor_);
    }

    function setChecker(address checker_) external onlyOwner {
        checker = checker_;
        emit SetChecker(checker_);
    }

    /// @dev Constants, so `_hashTypedDataV4` does not read the name and version from storage.
    function _EIP712Name() internal pure override returns (string memory) {
        return "Pendle PT Looper";
    }

    function _EIP712Version() internal pure override returns (string memory) {
        return "1";
    }

    function _hashExecution(Execution memory execution) internal view returns (bytes32) {
        return _hashTypedDataV4(execution.encodeData());
    }

    function _hashTyped(IncreasePositionRequest memory req) internal view returns (bytes32) {
        return _hashTypedDataV4(req.encodeData());
    }

    function _hashTyped(DecreasePositionRequest memory req) internal view returns (bytes32) {
        return _hashTypedDataV4(req.encodeData());
    }

    function _hashTyped(SwapBridgeWithdrawAllRequest memory req) internal view returns (bytes32) {
        return _hashTypedDataV4(req.encodeData());
    }

    /// @dev The context of an iteration. `spokeMM` is zero off the box's spoke chain. `requestHash` is for events.
    struct Session {
        IPLoopPositionBox box;
        IMoneyMarket spokeMM;
        BoxData bd;
        MarketCtx marketCtx;
        bytes32 requestHash;
    }

    function approveRequest(address owner, bytes32 requestHash, bytes memory ownerSig)
        external
        onlyExecutorOrBoxOwner(owner)
    {
        require(
            msg.sender == owner || SignatureChecker.isValidSignatureNow(owner, requestHash, ownerSig),
            "PTLooper: invalid owner signature"
        );
        require(requestStatus[owner][requestHash] == RequestStatus.DEFAULT, "PTLooper: invalid request status");
        requestStatus[owner][requestHash] = RequestStatus.APPROVED;
        emit RequestApproved(owner, requestHash);
    }

    /// @dev Lets the owner stop a request without the executor. The executor uses it, e.g., after a one-shot request.
    function terminateRequest(address owner, bytes32 requestHash) external onlyExecutorOrBoxOwner(owner) {
        requestStatus[owner][requestHash] = RequestStatus.TERMINATED;
        emit RequestTerminated(owner, requestHash);
    }

    /// @dev Checks the request is approved and not expired. The caller checks the executor.
    function _authorizedSession(address owner, RequestHeader memory header, bytes32 requestHash)
        internal
        returns (Session memory s)
    {
        require(header.expiry > block.timestamp, "PTLooper: request expired"); // forge-lint: disable-line(block-timestamp)
        require(requestStatus[owner][requestHash] == RequestStatus.APPROVED, "PTLooper: invalid request status");

        return _session(owner, header.boxId, requestHash);
    }

    /// @dev No auth; the caller does it.
    function _session(address owner, bytes32 boxId, bytes32 requestHash) private returns (Session memory s) {
        (s.box, s.spokeMM, s.bd) = POSITION_BOX_FACTORY.deployPositionBoxAndMoneyMarket(owner, boxId);
        s.marketCtx = createMarketCtx(s.box, s.bd);
        s.requestHash = requestHash;
    }
}
