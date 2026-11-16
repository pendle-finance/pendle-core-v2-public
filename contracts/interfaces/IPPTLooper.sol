// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPLoopPositionBox} from "./IPLoopPositionBox.sol";
import {IPLoopPositionBoxFactory} from "./IPLoopPositionBoxFactory.sol";
import {IPPostPtLoopStateChecker} from "../interfaces/IPPostPtLoopStateChecker.sol";

/// @notice The owner approves a request (EIP-712, in the looper's domain). The executor builds a message for
///         each iteration, and the checker signs the whole `execute`. The box is `(ms.owner, req.header.boxId)`.
interface IPPTLooperEIP712Types {
    /// @notice What the checker signs for `execute`. `calls` is hashed as an EIP-712 `bytes[]`.
    struct Execution {
        /// @notice The calls that `execute` runs in order, as delegatecalls into the looper.
        bytes[] calls;
        /// @notice The last timestamp at which `execute` can run.
        uint256 deadline;
    }

    /// @notice A request runs iterations until it is terminated or expires. A box can have more than one
    ///         live request. `offchainMetadataHash` is `keccak256(offchainMetadata)`; the contract does not read it.
    struct RequestHeader {
        bytes32 boxId;
        uint256 expiry;
        uint256 swapBridgeSlippage;
        bytes32 offchainMetadataHash;
    }

    struct BoxApprovedCall {
        address extRouter;
        address approve;
        bytes callData;
    }

    /// @notice Cross-chain only. `maxAmount`: the max amount to bridge. `nativeFee`: the native fee of the call.
    struct BridgeData {
        BoxApprovedCall call;
        uint256 maxAmount;
        uint256 nativeFee;
    }

    struct IncreasePositionRequest {
        RequestHeader header;
        /// @notice The token that an iteration with `swapInitToken` swaps.
        address initTokenIn;
        /// @notice Min `netOut / netIn` (WAD) of an `initTokenIn` to PT swap. 0: no check.
        uint256 initMinToPtSwapRate;
        /// @notice Min `netOut / netIn` (WAD) of a debt token to PT swap. 0: no check.
        uint256 minDebtToPtSwapRate;
        /// @notice Max `debt / (collateral * oracle rate)` (WAD) after the iteration.
        uint256 postBorrowMaxLTV;
        /// @notice true: the swap mints PT + YT 1:1, and the YT goes to the owner.
        bool isZeroPriceImpact;
    }

    struct IncreasePositionMessage {
        address owner;
        // Hub only.
        /// @notice true: swap `req.initTokenIn` to PT. false: swap the debt token to PT. The fee is in the
        ///         token that is swapped.
        bool swapInitToken;
        /// @notice `extRouter == address(0)`: no swap.
        BoxApprovedCall swap;
        /// @notice Min `netOut / netIn` (WAD) of the swap; the higher of this and the request's rate applies.
        uint256 minSwapRate;
        uint256 fee;

        // Cross-chain only: the hub bridges PT to the spoke; the spoke bridges debt back to the hub.
        BridgeData bridge;
        // Spoke only: lend, then borrow.
        uint256 amountDebtBorrowed;
        /// @notice Same-chain only. Debt token that the box flash-borrows from Morpho and pays back out of the
        ///         borrowed debt. 0: no flash loan.
        uint256 flashAmount;

        bytes postStateCheckData;
    }

    struct DecreasePositionRequest {
        RequestHeader header;
        /// @notice Min `netOut / netIn` (WAD) of a PT to debt token swap. 0: no check.
        uint256 minPtToDebtSwapRate;
        /// @notice Max `debt / (collateral * oracle rate)` (WAD) after the iteration.
        uint256 postWithdrawMaxLTV;
        /// @notice Hub only. true: the router redeems min(PT, YT) of the box 1:1 to the debt token. The rest
        ///         of the PT stays in the box. The owner sends the YT to the box first.
        bool redeemWithPY;
    }

    struct DecreasePositionMessage {
        address owner;
        // Hub only: swap PT to the debt token.
        /// @notice `extRouter == address(0)`: no swap. See `DecreasePositionRequest.redeemWithPY`.
        BoxApprovedCall swap;
        /// @notice Min `netOut / netIn` (WAD) of the swap; the higher of this and the request's rate applies.
        uint256 minSwapRate;
        // Cross-chain only: the hub bridges debt to the spoke; the spoke bridges PT back to the hub.
        BridgeData bridge;
        // Spoke only: repay, then withdraw.
        uint256 amountPtWithdrawn;
        /// @notice Hub only. In the debt token, out of the swap's output.
        uint256 fee;
        /// @notice Same-chain only. Debt token that the box flash-borrows from Morpho and pays back out of the
        ///         swap's output. 0: no flash loan.
        uint256 flashAmount;

        bytes postStateCheckData;
    }

    /// @notice Swaps the box's whole debt token balance on this chain to the token out, then sends it to the
    ///         owner, or bridges it when the destination is the other chain.
    struct SwapBridgeWithdrawAllRequest {
        RequestHeader header;
        /// @notice true: the destination is the spoke. false: the hub.
        bool receiveOnSpoke;
        /// @notice The token out on the hub, when the iteration runs on the hub.
        address hubTokenOut;
        /// @notice The token out on the destination chain.
        address dstTokenOut;
        /// @notice Min box balance of the token out after the swap.
        uint256 minTokenWithdrawn;
    }

    struct SwapBridgeWithdrawAllMessage {
        address owner;
        BoxApprovedCall swap;
        /// @notice Min `netOut / netIn` (WAD) of the swap. 0: no check.
        uint256 minSwapRate;
        BridgeData bridge;

        bytes postStateCheckData;
    }
}

interface IPPTLooper is IPPTLooperEIP712Types {
    /// @notice `DEFAULT`: cannot run. `APPROVED` (`approveRequest`): can run. `TERMINATED` (`terminateRequest`,
    ///         from any status): cannot run again. An iteration does not change the status.
    enum RequestStatus {
        DEFAULT,
        APPROVED,
        TERMINATED
    }

    event RequestApproved(address indexed owner, bytes32 requestHash);

    event RequestTerminated(address indexed owner, bytes32 requestHash);

    event SetExecutor(address executor);

    event SetChecker(address checker);

    event TokenSwapped(
        IPLoopPositionBox indexed box,
        address indexed tokenIn,
        uint256 netIn,
        address indexed tokenOut,
        uint256 netSwappedOut
    );

    event PYRedeemed(
        IPLoopPositionBox indexed box,
        address indexed pt,
        uint256 netPyIn,
        address indexed tokenOut,
        uint256 netSwappedOut
    );

    event TokenBridged(IPLoopPositionBox indexed box, address indexed token, uint256 amount);

    /// @notice The `box` flash-borrowed `amount` of `token` for this iteration, repaid at the end.
    ///         `preDebtBalance` and `preInBalance` (when swapping the debt token) count the loan,
    ///         and so do the swap input and money market amounts. `postDebtBalance` does not include it.
    event FlashLoaned(IPLoopPositionBox indexed box, address indexed token, uint256 amount);

    /// @notice The money market adapter emits no events.
    event MoneyMarketLentThenBorrowed(IPLoopPositionBox indexed box, uint256 ptLent, uint256 debtBorrowed);

    /// @notice The money market adapter emits no events.
    event MoneyMarketRepaidThenWithdrawn(IPLoopPositionBox indexed box, uint256 debtRepaid, uint256 ptWithdrawn);

    event PositionIncreased(
        address indexed owner,
        bytes32 indexed boxId,
        bytes32 requestHash,
        /// @notice Hub only. The box's pre-fee balance of the token swapped (`initTokenIn` or the debt token).
        uint256 preInBalance,
        uint256 netPtToMM,
        /// @notice Spoke only.
        uint256 postDebtBalance
    );

    event PositionDecreased(
        address indexed owner,
        bytes32 indexed boxId,
        bytes32 requestHash,
        /// @notice Spoke only.
        uint256 preDebtBalance,
        uint256 netPtToSwap,
        /// @notice Hub only. After the fee.
        uint256 postDebtBalance
    );

    event Withdrawn(
        address indexed owner, bytes32 indexed boxId, bytes32 requestHash, address tokenOut, uint256 netOut
    );

    // ========== Getters ==========

    function POSITION_BOX_FACTORY() external view returns (IPLoopPositionBoxFactory);

    function POST_LOOP_STATE_CHECKER() external view returns (IPPostPtLoopStateChecker);

    function executor() external view returns (address);

    function checker() external view returns (address);

    function requestStatus(address owner, bytes32 requestHash) external view returns (RequestStatus);

    // ========== Actions ==========

    // Each action runs one iteration, executor only, inside `execute`. The request must be approved and not expired.

    function increaseLoopPosition(IncreasePositionMessage memory ms, IncreasePositionRequest memory req) external;

    function decreaseLoopPosition(DecreasePositionMessage memory ms, DecreasePositionRequest memory req) external;

    function swapBridgeWithdrawAll(SwapBridgeWithdrawAllMessage memory ms, SwapBridgeWithdrawAllRequest memory req)
        external;

    /// @notice Approves a `DEFAULT` request. `requestHash` is the request's EIP-712 digest. The owner calls it,
    ///         or the executor calls it inside `execute` with the owner's signature of `requestHash`.
    function approveRequest(address owner, bytes32 requestHash, bytes memory ownerSig) external;

    /// @notice The request cannot run again. The owner calls it, or the executor inside `execute`.
    function terminateRequest(address owner, bytes32 requestHash) external;

    /// @notice Executor only, inside `execute`. Needs no request: funds go only to the owner or into the
    ///         owner's position. In order: `repayDebt` repays as much debt as the box's
    ///         debt token balance covers, `lendPt` lends its whole PT balance, then each token in `tokensToOwner`
    ///         goes to the owner in full.
    ///         `repayDebt` and `lendPt` need the spoke chain.
    function settleBox(address owner, bytes32 boxId, bool repayDebt, bool lendPt, address[] calldata tokensToOwner)
        external;

    /// @notice The executor's only entry point. Runs `execution.calls` in order as delegatecalls into this
    ///         contract; any failure reverts all. With `tx.origin == 0` (an `eth_call` with no `from`) it is a
    ///         simulation: no checker signature or deadline.
    /// @param execution the calls and the deadline.
    /// @param checkerSig the checker's EIP-712 signature over `execution`.
    /// @return results the return data of each call.
    function execute(Execution memory execution, bytes calldata checkerSig) external returns (bytes[] memory results);

    // ========== Admin functions ==========

    function setExecutor(address executor) external;

    function setChecker(address checker) external;
}
