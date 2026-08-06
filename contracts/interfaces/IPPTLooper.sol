// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPLoopPositionBox} from "./IPLoopPositionBox.sol";
import {IPLoopPositionBoxFactory} from "./IPLoopPositionBoxFactory.sol";
import {IPPostPtLoopStateChecker} from "../interfaces/IPPostPtLoopStateChecker.sol";

interface IPPTLooperEIP712Types {
    /// @notice Per-iteration permit, proposer-signed. Binds the iteration to a `(owner, boxId)`
    /// session; `nonce` matches `proposerNonce[owner][requestHash]`.
    struct BoxPermit {
        address owner;
        bytes32 boxId;
        uint256 expiry;
        uint256 nonce;
    }

    /// @notice Shared header on every user-signed request. `sessionNonce` bumps on
    /// `terminateSession` (defeats cross-session replay); `permitNonceCap` caps iterations.
    struct RequestHeader {
        bytes32 boxId;
        uint256 expiry;
        uint32 sessionNonce;
        uint32 permitNonceCap;
        uint256 swapBridgeSlippage;
        bytes offchainMetadata;
    }

    struct BoxApprovedCall {
        address extRouter;
        address approve;
        bytes callData;
    }

    /// @notice Bridge parameters shared by every cross-chain message.
    /// - `call`: the bridge router approve+call payload.
    /// - `maxAmount`: per-iteration cap on the bridged amount (proposer-imposed).
    /// - `nativeFee`: native fee forwarded to the bridge call.
    struct BridgeData {
        BoxApprovedCall call;
        uint256 maxAmount;
        uint256 nativeFee;
    }

    struct IncreasePositionRequest {
        RequestHeader header;
        /// First iteration data. User can directly transfer any token into the box.
        /// See `IncreasePositionMessage`.
        address initTokenIn;
        uint256 initMinToPtSwapRate;

        uint256 minDebtToPtSwapRate;
        uint256 postBorrowMaxLTV;
        /// @notice when true, the "swap" is a 1:1 PT+YT mint via SY; the co-minted YT is
        ///         immediately withdrawn to the owner.
        bool isZeroPriceImpact;
    }

    struct IncreasePositionMessage {
        BoxPermit permit;
        // Hub-only.
        /// @notice In the first iteration, swap initTokenIn->PT. Fee is in initTokenIn.
        /// @notice In subsequent iterations, swap debtToken->PT. Fee is in debtToken.
        /// @notice Set extRouter to address(0) to disable swapping.
        BoxApprovedCall swap;
        uint256 fee;

        // Cross-chain only: hub bridges PT to spoke; spoke bridges debt back to hub.
        BridgeData bridge;
        // Spoke-only: lend then borrow.
        uint256 amountDebtBorrowed;

        bytes postStateCheckData;
    }

    struct DecreasePositionRequest {
        RequestHeader header;
        uint256 minPtToDebtSwapRate;
        uint256 postWithdrawMaxLTV;
    }

    struct DecreasePositionMessage {
        BoxPermit permit;
        // Hub-only: swap PT→debtToken.
        /// @notice Set extRouter to address(0) to disable swapping.
        BoxApprovedCall swap;
        // Cross-chain only: hub bridges debt to spoke; spoke bridges PT back to hub.
        BridgeData bridge;
        // Spoke-only: repay then withdraw.
        uint256 amountPtWithdrawn;
        /// @notice Hub-only. Fee is in debtToken, taken out of the swap's output.
        uint256 fee;

        bytes postStateCheckData;
    }

    /// @notice Withdraw the current `hubDebtToken`. Supports both orderings:
    /// - swap-then-bridge: `hubDebtToken -> hubTokenOut -> dstTokenOut`
    /// - bridge-then-swap: `hubDebtToken -> spokeDebtToken -> dstTokenOut` (set `hubTokenOut = hubDebtToken`)
    /// @notice `minTokenWithdrawn` is the minimum amount of `hubTokenOut`/`dstTokenOut` to move out from box.
    struct SwapBridgeWithdrawAllRequest {
        RequestHeader header;
        bool receiveOnSpoke;
        address hubTokenOut;
        address dstTokenOut;
        uint256 minTokenWithdrawn;
    }

    struct SwapBridgeWithdrawAllMessage {
        BoxPermit permit;
        BoxApprovedCall swap;
        BridgeData bridge;

        bytes postStateCheckData;
    }

    struct ClaimMMRewardsRequest {
        RequestHeader header;
        address extRewardController;
        bytes data;
        address[] rewardTokens;
    }

    struct ClaimMMRewardsMessage {
        BoxPermit permit;
    }
}

interface IPPTLooper is IPPTLooperEIP712Types {
    struct UserRequestInfo {
        bytes32 requestHash;
        uint32 sessionNonce;
    }

    /// @notice Emitted on the first iteration call of a session, when the implicit init branch
    /// runs (owner signature verified, `userReq.requestHash` set). `sessionNonce` is the
    /// pre-increment value the session was opened with.
    event SessionInitiated(address indexed owner, bytes32 indexed boxId, bytes32 requestHash, uint32 sessionNonce);

    /// @notice Emitted by `terminateSession`. `sessionNonce` is the post-increment value that
    /// the next user request must match.
    event SessionTerminated(address indexed owner, bytes32 indexed boxId, bytes32 requestHash, uint32 sessionNonce);

    event SetExecutor(address executor);

    event SetProposer(address proposer);

    event TokenSwapped(
        IPLoopPositionBox indexed box,
        address indexed tokenIn,
        uint256 netIn,
        address indexed tokenOut,
        uint256 netSwappedOut
    );

    event TokenBridged(IPLoopPositionBox indexed box, address indexed token, uint256 amount);

    event MoneyMarketLentThenBorrowed(IPLoopPositionBox indexed box, uint256 ptLent, uint256 debtBorrowed);

    event MoneyMarketRepaidThenWithdrawn(IPLoopPositionBox indexed box, uint256 debtRepaid, uint256 ptWithdrawn);

    event PositionIncreased(
        address indexed owner,
        bytes32 indexed boxId,
        bytes32 requestHash,
        uint256 nonce,
        /// @notice this field is filled only on hub chain
        /// @notice on first iteration, this is the balance of initTokenIn
        uint256 preInBalance,
        uint256 netPtToMM,
        /// @notice this field is filled only on spoke chain
        uint256 postDebtBalance
    );

    event PositionDecreased(
        address indexed owner,
        bytes32 indexed boxId,
        bytes32 requestHash,
        uint256 nonce,
        /// @notice this field is filled only on spoke chain
        uint256 preDebtBalance,
        uint256 netPtToSwap,
        /// @notice this field is filled only on hub chain
        uint256 postDebtBalance
    );

    event Withdrawn(
        address indexed owner,
        bytes32 indexed boxId,
        bytes32 requestHash,
        uint256 nonce,
        address tokenOut,
        uint256 netOut
    );

    event RewardsClaimed(
        address indexed owner,
        bytes32 indexed boxId,
        bytes32 requestHash,
        uint256 nonce,
        address[] rewardTokens,
        uint256[] claimedAmounts
    );

    // ========== Getters ==========

    function POSITION_BOX_FACTORY() external view returns (IPLoopPositionBoxFactory);

    function POST_LOOP_STATE_CHECKER() external view returns (IPPostPtLoopStateChecker);

    function executor() external view returns (address);

    function proposer() external view returns (address);

    function proposerNonce(address owner, bytes32 requestHash) external view returns (uint256);

    function userRequest(address owner, bytes32 boxId) external view returns (UserRequestInfo memory);

    // ========== Hash functions (exposed for off-chain typed-data tooling) ==========

    function hashRaw(BoxPermit memory permit) external pure returns (bytes32);

    function hashRaw(RequestHeader memory header) external pure returns (bytes32);

    function hashRaw(BoxApprovedCall memory call) external pure returns (bytes32);

    function hashRaw(BridgeData memory bridge) external pure returns (bytes32);

    function hashRaw(IncreasePositionRequest memory req) external pure returns (bytes32);

    function hashRaw(DecreasePositionRequest memory req) external pure returns (bytes32);

    function hashRaw(SwapBridgeWithdrawAllRequest memory req) external pure returns (bytes32);

    function hashRaw(ClaimMMRewardsRequest memory req) external view returns (bytes32);

    function hashRaw(ClaimMMRewardsMessage memory ms) external view returns (bytes32);

    function hashTyped(IncreasePositionRequest memory req) external view returns (bytes32);

    function hashTyped(IncreasePositionMessage memory ms) external view returns (bytes32);

    function hashTyped(DecreasePositionRequest memory req) external view returns (bytes32);

    function hashTyped(DecreasePositionMessage memory ms) external view returns (bytes32);

    function hashTyped(SwapBridgeWithdrawAllRequest memory req) external view returns (bytes32);

    function hashTyped(SwapBridgeWithdrawAllMessage memory ms) external view returns (bytes32);

    function hashTyped(ClaimMMRewardsRequest memory req) external view returns (bytes32);

    function hashTyped(ClaimMMRewardsMessage memory ms) external view returns (bytes32);

    // ========== Actions ==========

    /// @notice One increase iteration. The first call for a `(owner, boxId)` slot also opens
    ///         the session — pass the owner's typed-data signature over `req` in
    ///         `ownerSigIfFirstCall`. Subsequent iterations within the same session can pass
    ///         empty bytes for that arg (it is ignored once the session is open).
    function increaseLoopPosition(
        IncreasePositionMessage memory ms,
        bytes memory proposerSig,
        IncreasePositionRequest memory req,
        bytes memory ownerSigIfFirstCall
    ) external payable;

    function decreaseLoopPosition(
        DecreasePositionMessage memory ms,
        bytes memory proposerSig,
        DecreasePositionRequest memory req,
        bytes memory ownerSigIfFirstCall
    ) external payable;

    function swapBridgeWithdrawAll(
        SwapBridgeWithdrawAllMessage memory ms,
        bytes memory proposerSig,
        SwapBridgeWithdrawAllRequest memory req,
        bytes memory ownerSigIfFirstCall
    ) external payable;

    /// @notice Closes the open session at `(owner, boxId)`. `requestHash` must equal the
    ///         currently-stored `userReq.requestHash` (proves the caller identifies which
    ///         session is being closed). Bumps `sessionNonce`, clears `requestHash`.
    function terminateSession(address owner, bytes32 boxId, bytes32 requestHash) external;

    function claimMMRewards(
        ClaimMMRewardsMessage memory ms,
        bytes memory proposerSig,
        ClaimMMRewardsRequest memory req,
        bytes memory ownerSigIfFirstCall
    ) external;

    // ========== Admin functions ==========

    function setExecutor(address executor) external;

    function setProposer(address proposer) external;
}
