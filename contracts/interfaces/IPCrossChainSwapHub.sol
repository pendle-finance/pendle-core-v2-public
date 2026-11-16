// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPCrossChainSwapHub {
    error InsufficientTokenReceived();
    error InvalidNonce();
    error InvalidSignature();
    error MessageExpired();
    error Unauthorized();

    struct BoxPermit {
        address owner;
        uint32 boxId;
        uint256 expiry;
        uint256 requestId;
        uint256 nonce;
    }

    struct WithdrawTokenMessage {
        BoxPermit permit;
        address token;
        uint256 amountWithdraw;
        uint256 amountFee;
    }

    struct BridgeTokenMessage {
        BoxPermit permit;
        address token;
        uint256 amountBridge;
        uint256 amountFee;
        //
        address bridgeExtRouter;
        address bridgeApprove;
        bytes bridgeCalldata;
    }

    struct SwapTokenMessage {
        BoxPermit permit;
        address tokenSpent;
        uint256 amountSpent;
        address tokenReceived;
        uint256 minReceived;
        //
        address swapExtRouter;
        address swapApprove;
        bytes swapCalldata;
    }

    event WithdrawToken(
        address owner,
        uint32 boxId,
        uint256 requestId,
        uint256 nonce,
        address token,
        uint256 amountWithdraw,
        uint256 amountFee
    );

    event BridgeToken(
        address owner,
        uint32 boxId,
        uint256 requestId,
        uint256 nonce,
        address bridgeExtRouter,
        address token,
        uint256 amountBridge,
        uint256 amountFee
    );

    event SwapToken(
        address owner,
        uint32 boxId,
        uint256 requestId,
        uint256 nonce,
        address tokenSpent,
        uint256 amountSpent,
        address tokenReceived,
        uint256 netTokenReceived
    );

    event SetExecutor(address executor);

    event SetProposer(address proposer);

    function executor() external view returns (address);

    function proposer() external view returns (address);

    function setExecutor(address executor) external;

    function setProposer(address proposer) external;

    function requestNonce(uint256 requestId) external view returns (uint256);

    function hashBoxPermit(BoxPermit memory permit) external view returns (bytes32);

    function hashTypedData(WithdrawTokenMessage memory message) external view returns (bytes32);

    function hashTypedData(BridgeTokenMessage memory message) external view returns (bytes32);

    function hashTypedData(SwapTokenMessage memory message) external view returns (bytes32);

    function withdrawToken(WithdrawTokenMessage memory message, bytes memory signature) external;

    function bridgeToken(BridgeTokenMessage memory message, bytes memory signature) external payable;

    function swapToken(SwapTokenMessage memory message, bytes memory signature) external;
}
